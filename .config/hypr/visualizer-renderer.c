/* Native, click-through Cairo spectrum surfaces. Audio arrives from Bash/CAVA. */
#include <gtk/gtk.h>
#include <gtk-layer-shell.h>
#include <glib-unix.h>
#include <math.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define BANDS 64
#define DEPTH 16
typedef struct { double target[BANDS], shown[BANDS], envelope; } Spectrum;
typedef struct { GtkWidget *window; GdkMonitor *monitor; int edge; } Surface;
static Spectrum spectrum;
static GPtrArray *surfaces;
static gint64 last_frame, last_tick;
static gboolean input_failed;

static gboolean ingest(Spectrum *s, const char *line) {
    double values[BANDS], peak = 0;
    for (int i = 0; i < BANDS; i++) {
        char *end;
        values[i] = g_ascii_strtod(line, &end);
        if (end == line || !isfinite(values[i]) || values[i] < 0 || values[i] > 65535)
            return FALSE;
        if (*end != ';' && !(i == BANDS - 1 && (*end == '\n' || !*end))) return FALSE;
        line = *end == ';' ? end + 1 : end;
        peak = MAX(peak, values[i]);
    }
    if (*line && strcmp(line, "\n")) return FALSE;
    s->envelope = MAX(1, MAX(peak, s->envelope * 0.8));
    for (int i = 0; i < BANDS; i++) s->target[i] = values[i] / s->envelope;
    return TRUE;
}

static double height_at(const Spectrum *s, double x, double length) {
    double p = CLAMP(x / MAX(1, length), 0, 1) * (BANDS - 1);
    int i = MIN((int)p, BANDS - 2);
    double t = p - i;
    double a = s->shown[MAX(0, i - 1)], b = s->shown[i];
    double c = s->shown[i + 1], d = s->shown[MIN(BANDS - 1, i + 2)];
    /* Catmull-Rom interpolation keeps the curve smooth between frequency bins. */
    double value = 0.5 * ((2*b) + (-a+c)*t + (2*a-5*b+4*c-d)*t*t + (-a+3*b-3*c+d)*t*t*t);
    double distance = MAX(0, MIN(x, length - x));
    /* Restore the old one-step corner tips and four-column (~32px) taper,
       expressed in pixels so the continuous renderer needs no font metrics. */
    double cap = MIN(DEPTH - 2, 1.75 + distance * 0.4375);
    return MIN(CLAMP(value, 0, 1) * (DEPTH - 2), cap);
}

static void point(cairo_t *cr, int edge, double x, double h, double width, double height) {
    switch (edge) {
        case 0: cairo_line_to(cr, x, h); break;
        case 1: cairo_line_to(cr, x, height - h); break;
        case 2: cairo_line_to(cr, h, x); break;
        default: cairo_line_to(cr, width - h, x); break;
    }
}

static gboolean draw(GtkWidget *widget, cairo_t *cr, gpointer data) {
    Surface *surface = data;
    double width = gtk_widget_get_allocated_width(widget);
    double height = gtk_widget_get_allocated_height(widget);
    double length = surface->edge < 2 ? width : height;
    cairo_set_operator(cr, CAIRO_OPERATOR_SOURCE);
    cairo_set_source_rgba(cr, 0, 0, 0, 0);
    cairo_paint(cr);
    cairo_set_operator(cr, CAIRO_OPERATOR_OVER);
    double maximum = 0;
    for (int i = 0; i < BANDS; i++) maximum = MAX(maximum, spectrum.shown[i]);
    if (maximum < 0.002) return TRUE;
    point(cr, surface->edge, 0, 0, width, height);
    for (double x = 0; x < length; x += 1)
        point(cr, surface->edge, x, height_at(&spectrum, x, length), width, height);
    point(cr, surface->edge, length, height_at(&spectrum, length, length), width, height);
    point(cr, surface->edge, length, 0, width, height);
    cairo_close_path(cr);
    cairo_set_source_rgba(cr, 103.0/255, 1, 235.0/255, 0.85);
    cairo_fill(cr);
    return TRUE;
}

static void passthrough(GtkWidget *widget, gpointer unused) {
    (void)unused;
    cairo_region_t *region = cairo_region_create();
    gdk_window_input_shape_combine_region(gtk_widget_get_window(widget), region, 0, 0);
    cairo_region_destroy(region);
}

static void free_surface(gpointer data) {
    Surface *surface = data;
    gtk_widget_destroy(surface->window);
    g_object_unref(surface->monitor);
    g_free(surface);
}

static void add_monitor(GdkDisplay *display, GdkMonitor *monitor, gpointer unused) {
    (void)display; (void)unused;
    for (int edge = 0; edge < 4; edge++) {
        Surface *s = g_new0(Surface, 1);
        s->edge = edge;
        s->monitor = g_object_ref(monitor);
        s->window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
        GtkWindow *window = GTK_WINDOW(s->window);
        gtk_window_set_decorated(window, FALSE);
        gtk_window_set_accept_focus(window, FALSE);
        gtk_widget_set_app_paintable(s->window, TRUE);
        gtk_widget_set_visual(s->window, gdk_screen_get_rgba_visual(gtk_widget_get_screen(s->window)));
        gtk_layer_init_for_window(window);
        gtk_layer_set_namespace(window, "dots-visualizer");
        gtk_layer_set_monitor(window, monitor);
        gtk_layer_set_layer(window, GTK_LAYER_SHELL_LAYER_BOTTOM);
        gtk_layer_set_keyboard_mode(window, GTK_LAYER_SHELL_KEYBOARD_MODE_NONE);
        gtk_layer_set_exclusive_zone(window, 0);
        gtk_layer_set_anchor(window, GTK_LAYER_SHELL_EDGE_TOP, edge != 1);
        gtk_layer_set_anchor(window, GTK_LAYER_SHELL_EDGE_BOTTOM, edge != 0);
        gtk_layer_set_anchor(window, GTK_LAYER_SHELL_EDGE_LEFT, edge != 3);
        gtk_layer_set_anchor(window, GTK_LAYER_SHELL_EDGE_RIGHT, edge != 2);
        gtk_widget_set_size_request(s->window, edge < 2 ? 1 : DEPTH, edge < 2 ? DEPTH : 1);
        g_signal_connect(s->window, "realize", G_CALLBACK(passthrough), NULL);
        g_signal_connect(s->window, "draw", G_CALLBACK(draw), s);
        g_ptr_array_add(surfaces, s);
        gtk_widget_show_all(s->window);
    }
}

static void remove_monitor(GdkDisplay *display, GdkMonitor *monitor, gpointer unused) {
    (void)display; (void)unused;
    for (guint i = surfaces->len; i > 0; i--) {
        Surface *s = g_ptr_array_index(surfaces, i - 1);
        if (s->monitor == monitor) g_ptr_array_remove_index(surfaces, i - 1);
    }
}

static double advance_value(double old, double target, double dt) {
    /* Immediate attack keeps beats on time; a short release avoids flicker. */
    return target >= old ? target : target + (old - target) * exp(-dt / 0.035);
}

static gboolean tick(gpointer unused) {
    (void)unused;
    gint64 now = g_get_monotonic_time();
    double dt = MIN(0.1, (now - last_tick) / 1e6);
    last_tick = now;
    gboolean changed = FALSE;
    for (int i = 0; i < BANDS; i++) {
        double target = now - last_frame > 1000000 ? 0 : spectrum.target[i];
        double old = spectrum.shown[i];
        double next = advance_value(old, target, dt);
        if (fabs(next - target) < 0.0001) next = target;
        spectrum.shown[i] = next;
        if (next != old) changed = TRUE;
    }
    if (changed) for (guint i = 0; i < surfaces->len; i++) {
        Surface *s = g_ptr_array_index(surfaces, i);
        gtk_widget_queue_draw(s->window);
    }
    return G_SOURCE_CONTINUE;
}

static gboolean audio_ready(GIOChannel *channel, GIOCondition condition, gpointer unused) {
    (void)unused;
    gboolean updated = FALSE;
    for (;;) {
        gchar *line = NULL;
        GIOStatus status = g_io_channel_read_line(channel, &line, NULL, NULL, NULL);
        if (status == G_IO_STATUS_NORMAL) {
            if (ingest(&spectrum, line)) {
                last_frame = g_get_monotonic_time();
                updated = TRUE;
            }
            g_free(line);
        } else {
            g_free(line);
            if (status == G_IO_STATUS_AGAIN && !(condition & (G_IO_HUP | G_IO_ERR))) {
                if (updated) tick(NULL);
                return G_SOURCE_CONTINUE;
            }
            input_failed = TRUE;
            gtk_main_quit();
            return G_SOURCE_REMOVE;
        }
    }
}

static gboolean stop(gpointer unused) {
    (void)unused;
    gtk_main_quit();
    return G_SOURCE_REMOVE;
}

static void self_test(void) {
    Spectrum a = {0}, b = {0};
    GString *loud = g_string_new(NULL), *quiet = g_string_new(NULL);
    for (int i = 0; i < BANDS; i++) {
        g_string_append_printf(loud, "%d;", i * 1000);
        g_string_append_printf(quiet, "%d;", i);
    }
    g_assert(ingest(&a, loud->str) && ingest(&b, quiet->str));
    for (int i = 0; i < BANDS; i++) {
        g_assert(fabs(a.target[i] - b.target[i]) < 1e-9);
        a.shown[i] = 1;
    }
    g_assert(!ingest(&a, "bad;input;") && !ingest(&a, "1;2;"));
    for (int length = 100; length <= 4000; length += 100) {
        g_assert(height_at(&a, 0, length) == 1.75 && height_at(&a, length, length) == 1.75);
        for (int x = 0; x <= length; x++) {
            double height = height_at(&a, x, length);
            g_assert(height >= 0 && height <= DEPTH - 2);
            g_assert(height <= 1.75 + MIN(x, length - x) * 0.4375 + 1e-9);
        }
    }
    g_assert(advance_value(0, 1, 0.001) == 1);
    g_assert(advance_value(1, 0, 0.09) < 0.08);
    g_string_free(loud, TRUE); g_string_free(quiet, TRUE);
    g_print("PASS: native normalization, parser, corner tips and immediate attack\n");
}

int main(int argc, char **argv) {
    if (argc == 2 && !strcmp(argv[1], "--self-test")) { self_test(); return 0; }
    if (argc == 2 && !strcmp(argv[1], "--analyze")) {
        char *line = NULL; size_t capacity = 0;
        while (getline(&line, &capacity, stdin) >= 0) if (ingest(&spectrum, line)) {
            double peak = 0;
            for (int i = 0; i < BANDS; i++) peak = MAX(peak, spectrum.target[i]);
            printf("{\"peak\":%.6f}\n", peak * 8);
        }
        free(line); return 0;
    }
    if (!gtk_init_check(&argc, &argv) || !gtk_layer_is_supported()) {
        g_printerr("A Wayland session with layer-shell support is required\n"); return 1;
    }
    surfaces = g_ptr_array_new_with_free_func(free_surface);
    GdkDisplay *display = gdk_display_get_default();
    g_signal_connect(display, "monitor-added", G_CALLBACK(add_monitor), NULL);
    g_signal_connect(display, "monitor-removed", G_CALLBACK(remove_monitor), NULL);
    for (int i = 0; i < gdk_display_get_n_monitors(display); i++)
        add_monitor(display, gdk_display_get_monitor(display, i), NULL);
    GIOChannel *input = g_io_channel_unix_new(0);
    g_io_channel_set_encoding(input, NULL, NULL);
    g_io_channel_set_flags(input, G_IO_FLAG_NONBLOCK, NULL);
    g_io_add_watch(input, G_IO_IN | G_IO_HUP | G_IO_ERR, audio_ready, NULL);
    last_tick = last_frame = g_get_monotonic_time();
    g_timeout_add(16, tick, NULL);
    g_unix_signal_add(SIGTERM, stop, NULL);
    g_unix_signal_add(SIGINT, stop, NULL);
    gtk_main();
    g_io_channel_unref(input);
    g_ptr_array_free(surfaces, TRUE);
    if (input_failed) g_printerr("CAVA input closed\n");
    return input_failed ? 1 : 0;
}
