/* A text-only garden with persistent seed/age and bounded living geometry. */
#include <gtk/gtk.h>
#include <gtk-layer-shell.h>
#include <glib-unix.h>
#include <errno.h>
#include <fcntl.h>
#include <math.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/file.h>
#include <unistd.h>

#define COLS 81
#define ROWS 39
#define MATURITY (450.0 * 3600) /* 75 days at six awake hours per day. */
#define STARS 230
#define GLYPHS 95

typedef struct { guint32 seed; gint64 created; double seconds; } Tree;
typedef struct { char glyph; unsigned char color; } Cell;
typedef struct { double x, y, phase, speed; char glyph; } Star;
typedef struct { double x, y, dx, dy; } Flight;
typedef struct {
    GtkWidget *window;
    GdkMonitor *monitor;
    cairo_surface_t *glyphs[GLYPHS], *tree, *milky_way;
    double cw, ch;
    gint64 tree_hour;
    Star stars[STARS];
    double meteor_at;
    guint32 sky_seed, meteor_seed;
} Surface;
static Tree tree;
static char *state_path, *backup_path;

static guint32 hash(guint32 x) {
    x ^= x >> 16; x *= 0x7feb352dU;
    x ^= x >> 15; x *= 0x846ca68bU;
    return x ^ (x >> 16);
}
static double unit(guint32 x) { return hash(x) / 4294967296.0; }

static void put(Cell cells[ROWS][COLS], int x, int y, char glyph, int color) {
    if (x >= 0 && x < COLS && y >= 0 && y < ROWS - 3 &&
        (color == 1 || cells[y][x].glyph == 0))
        cells[y][x] = (Cell){glyph, (unsigned char)color};
}

/* Broad, shallow foliage pads and alternating branches give the tree a trained
   bonsai silhouette. The seed fixes its lean and small irregularities. */
static double trunk_x(const Tree *t, double p) {
    double lean = unit(t->seed) < 0.5 ? -1 : 1;
    double bend = 3.5 + unit(t->seed ^ 71) * 2.5;
    double turns = 1.9 + unit(t->seed ^ 149) * 0.6;
    double tilt = 1 + unit(t->seed ^ 233) * 4;
    return COLS / 2 + lean * (bend * sin(p * G_PI * turns) + p * tilt);
}

static void foliage(Cell cells[ROWS][COLS], const Tree *t, guint32 id,
                    double x, double y, double radius, double fullness) {
    guint32 season = (guint32)fmod(floor(t->seconds / (250 * 3600)), 4294967296.0);
    guint32 cycle = (guint32)fmod(floor(t->seconds / (40 * 3600)), 4294967296.0);
    double rx = MAX(1.5, radius * fullness), ry = MAX(1, 2.6 * fullness);
    for (int dy = -3; dy <= 3; dy++) for (int dx = -(int)ceil(rx); dx <= (int)ceil(rx); dx++) {
        double ellipse = dx * dx / (rx * rx) + dy * dy / (ry * ry);
        guint32 key = hash(t->seed ^ (id * 197 + (dx + 20) * 31 + dy + 4));
        if (ellipse > 1 + unit(key) * 0.18) continue;
        double gap = season % 4 == 3 ? 0.34 : 0.10;
        if (unit(key ^ cycle) < gap) continue;
        char c = season % 4 == 3 ? ".+'"[hash(key + cycle) % 3] : "*o+o"[hash(key + cycle) % 4];
        put(cells, (int)round(x) + dx, (int)round(y) + dy, c, season % 4 == 2 ? 4 : 2);
    }
}

static void garden(const Tree *t, Cell cells[ROWS][COLS]) {
    memset(cells, 0, sizeof(Cell) * ROWS * COLS);
    double growth = sqrt(CLAMP(t->seconds / MATURITY, 0, 1));
    double top = MAX(1.0 / 27, growth);
    /* Reveal a permanent S-shaped trunk from the roots upward. */
    for (int i = 0; i <= (int)(top * 108); i++) {
        double p = i / 108.0;
        double x = trunk_x(t, p), y = ROWS - 4 - p * 27;
        double dx = trunk_x(t, p + 0.01) - x;
        char edge = fabs(dx) < 0.05 ? '|' : dx < 0 ? '\\' : '/';
        int width = 1 + (int)((1 - p) * growth * 3);
        for (int w = 0; w < width; w++)
            put(cells, (int)round(x) + w - width / 2, (int)round(y),
                w == 0 || w == width - 1 ? edge : ':', 1);
    }
    /* Each branch joins an already-visible part of the trunk. Lower pads
       spread wider; upper pads taper toward the apex instead of a round crown. */
    for (int layer = 0; layer < 6; layer++) {
        double at = 0.18 + layer * 0.13 + (unit(t->seed ^ (layer + 307)) - 0.5) * 0.025;
        double progress = CLAMP((growth - at) / 0.15, 0, 1);
        if (progress <= 0) continue;
        int side = (layer % 2 ? 1 : -1) * (unit(t->seed) < 0.5 ? 1 : -1);
        double x = trunk_x(t, at), y = ROWS - 4 - at * 27;
        double length = 15 - layer * 1.4 + unit(t->seed + layer) * 5;
        double tip_x = x, tip_y = y;
        for (int step = 0; step <= (int)(length * progress * 2); step++) {
            double p = step / (length * 2);
            tip_x = x + side * length * p;
            tip_y = y - 2.5 * sin(p * G_PI / 2);
            put(cells, (int)round(tip_x), (int)round(tip_y), p < 0.3 ? (side < 0 ? '\\' : '/') : '_', 1);
        }
        double radius = 8.5 - layer * 0.5 + unit(t->seed ^ (layer + 419)) * 2.5;
        foliage(cells, t, layer + 1, tip_x, tip_y - 1, radius, 0.25 + progress * 0.75);
        if (growth == 1) {
            guint32 cycle = (guint32)fmod(floor(t->seconds / (40 * 3600)), 4294967296.0);
            int twig = hash(t->seed + layer + cycle) % 5 - 2;
            put(cells, (int)round(tip_x) + twig, (int)round(tip_y) - 3, twig < 0 ? '\\' : '/', 2);
        }
    }
    foliage(cells, t, 20, trunk_x(t, top), ROWS - 5 - top * 27, 7,
            0.18 + 0.82 * CLAMP((growth - 0.8) / 0.2, 0, 1));
    if (growth > 0.15) {
        const char *roots = "_/|\\_";
        for (int i = 0; roots[i]; i++) put(cells, COLS / 2 - 2 + i, ROWS - 4, roots[i], 1);
    }
    const char *pot[] = {
        "._________________________________.",
        " \\_______________________________/ ",
        "    |___|                 |___|    "
    };
    for (int row = 0; row < 3; row++) {
        int start = (COLS - (int)strlen(pot[row])) / 2;
        for (int col = 0; pot[row][col]; col++)
            cells[ROWS - 3 + row][start + col] = (Cell){pot[row][col], 3};
    }
}

static gboolean read_tree(const char *path, Tree *out) {
    char *text = NULL;
    if (!g_file_get_contents(path, &text, NULL, NULL)) return FALSE;
    unsigned version, seed;
    long long created;
    double seconds;
    int end = 0;
    gboolean valid = sscanf(text, "dots-garden %u %u %lld %lf %n", &version, &seed, &created, &seconds, &end) == 4 &&
        end > 0 && text[end] == '\0' && version == 1 && created > 0 &&
        isfinite(seconds) && seconds >= 0 && seconds <= 1e12;
    if (valid) *out = (Tree){seed, created, seconds};
    g_free(text);
    return valid;
}

static gboolean write_tree(const char *path, const Tree *t) {
    char *text = g_strdup_printf("dots-garden 1 %u %" G_GINT64_FORMAT " %.6f\n", t->seed, t->created, t->seconds);
    GError *error = NULL;
    gboolean ok = g_file_set_contents_full(path, text, -1,
        G_FILE_SET_CONTENTS_CONSISTENT | G_FILE_SET_CONTENTS_DURABLE, 0600, &error);
    if (!ok) { g_warning("Saving %s: %s", path, error->message); g_clear_error(&error); }
    g_free(text);
    return ok;
}

static gboolean save_tree(void) {
    Tree previous;
    if (read_tree(state_path, &previous) && !write_tree(backup_path, &previous)) return FALSE;
    return write_tree(state_path, &tree);
}

static gboolean load_tree(void) {
    if (read_tree(state_path, &tree)) return TRUE;
    if (read_tree(backup_path, &tree)) {
        g_warning("Recovered garden from last-good backup");
        return write_tree(state_path, &tree);
    }
    if (g_file_test(state_path, G_FILE_TEST_EXISTS) || g_file_test(backup_path, G_FILE_TEST_EXISTS)) {
        g_warning("Garden state is unreadable; restore state or state.bak rather than replacing the tree");
        return FALSE;
    }
    tree = (Tree){g_random_int(), g_get_real_time() / G_USEC_PER_SEC, 0};
    return write_tree(state_path, &tree) && write_tree(backup_path, &tree);
}

static double elapsed(gint64 now, gint64 previous) {
    /* Linux CLOCK_MONOTONIC (used by GLib) excludes suspend and wall-clock changes. */
    return MAX(0.0, (now - previous) / 1e6);
}

/* A bounded repeating event, independent of tree age and display frame rate. */
static double event_phase(double time, double period, double start, double duration) {
    double phase = fmod(time, period) - start;
    return phase >= 0 && phase < duration ? phase / duration : -1;
}

/* Choose a path once per event, so redraws never move it to a new location. */
static Flight flight(guint32 seed, gboolean comet) {
    double direction = unit(seed) < 0.5 ? -1 : 1;
    double x = 0.06 + unit(seed + 1) * 0.48;
    double y = 0.04 + unit(seed + 2) * 0.58;
    if (comet)
        return (Flight){direction > 0 ? -0.08 : 1.08, y,
            direction * 1.16, 0.06 + unit(seed + 3) * 0.66 - y};
    return (Flight){direction > 0 ? x : 1 - x, y,
        direction * (0.16 + unit(seed + 3) * 0.28), 0.08 + unit(seed + 4) * 0.20};
}

#ifndef GARDEN_TEST
static GPtrArray *surfaces;
static gboolean preview, frozen;
static guint animation_timer;
static double frozen_time;
static char *frozen_path;
static gint64 last_tick, last_save, started;
static int state_lock = -1;
static gboolean save_failed;
static const double colors[][3] = {
    {0.75, 0.79, 0.79}, {0.66, 0.73, 0.70}, {0.40, 0.76, 0.61},
    {0.30, 0.53, 0.50}, {0.77, 0.61, 0.36}, {0.40, 1.0, 0.92},
    {0.50, 0.65, 0.90}, {0.72, 0.55, 0.90}, {0.87, 0.56, 0.72}
};

static void glyph(Surface *s, cairo_t *cr, char c, double x, double y, int color, double alpha) {
    if (c < 32 || c > 126 || c == ' ') return;
    cairo_set_source_rgba(cr, colors[color][0], colors[color][1], colors[color][2], alpha);
    cairo_mask_surface(cr, s->glyphs[c - 32], round(x), round(y));
}

static void init_art(Surface *s) {
    PangoFontMap *map = pango_cairo_font_map_get_default();
    PangoContext *context = pango_font_map_create_context(map);
    PangoLayout *layout = pango_layout_new(context);
    /* The bundled patched TTC currently calls its family simply Monocraft. */
    PangoFontDescription *font = pango_font_description_from_string("Monocraft Nerd Font,Monocraft 12");
    pango_layout_set_font_description(layout, font);
    pango_layout_set_text(layout, "M", 1);
    int w, h;
    pango_layout_get_pixel_size(layout, &w, &h);
    s->cw = w; s->ch = h;
    for (int i = 0; i < GLYPHS; i++) {
        char c = (char)(i + 32);
        s->glyphs[i] = cairo_image_surface_create(CAIRO_FORMAT_A8, w, h);
        cairo_t *cr = cairo_create(s->glyphs[i]);
        pango_layout_set_text(layout, &c, 1);
        cairo_set_source_rgba(cr, 1, 1, 1, 1);
        pango_cairo_show_layout(cr, layout);
        cairo_destroy(cr);
    }
    pango_font_description_free(font);
    g_object_unref(layout); g_object_unref(context);
    s->tree_hour = -1;
    for (int i = 0; i < STARS; i++)
        s->stars[i] = (Star){g_random_double(), g_random_double(), g_random_double_range(0, 2 * G_PI),
            g_random_double_range(0.35, 1.1), ".+*"[g_random_int_range(0, 3)]};
    s->meteor_at = 2;
    s->sky_seed = g_random_int();
    s->meteor_seed = g_random_int();
}

static void cache_tree(Surface *s, double width, double height) {
    gint64 hour = (gint64)(tree.seconds / 3600);
    /* The mature trunk/canopy spans about 32 rows; blank grid rows and the
       pot should not count toward its half-screen height. Fit narrow outputs. */
    double scale = MIN(width * 0.90 / (COLS * s->cw), height * 0.50 / (32 * s->ch));
    int tw = MAX(1, (int)round(COLS * s->cw * scale));
    int th = MAX(1, (int)round(ROWS * s->ch * scale));
    if (s->tree && s->tree_hour == hour && cairo_image_surface_get_width(s->tree) == tw &&
        cairo_image_surface_get_height(s->tree) == th) return;
    if (s->tree) cairo_surface_destroy(s->tree);
    s->tree = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, (int)(COLS * s->cw), (int)(ROWS * s->ch));
    cairo_t *cr = cairo_create(s->tree);
    Cell cells[ROWS][COLS];
    garden(&tree, cells);
    /* Keep every gap transparent, including spaces inside the pot. */
    for (int y = 0; y < ROWS; y++) for (int x = 0; x < COLS; x++)
        glyph(s, cr, cells[y][x].glyph, x * s->cw, y * s->ch, cells[y][x].color, 0.9);
    cairo_destroy(cr);
    cairo_surface_t *scaled = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, tw, th);
    cr = cairo_create(scaled);
    cairo_scale(cr, tw / (COLS * s->cw), th / (ROWS * s->ch));
    cairo_set_source_surface(cr, s->tree, 0, 0);
    cairo_pattern_set_filter(cairo_get_source(cr), CAIRO_FILTER_BEST);
    cairo_paint(cr);
    cairo_destroy(cr);
    cairo_surface_destroy(s->tree);
    s->tree = scaled;
    s->tree_hour = hour;
}

static void milky_way(Surface *s, cairo_t *cr, int width, int height) {
    if (!s->milky_way || cairo_image_surface_get_width(s->milky_way) != width ||
        cairo_image_surface_get_height(s->milky_way) != height) {
        if (s->milky_way) cairo_surface_destroy(s->milky_way);
        s->milky_way = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, width, height);
        cairo_t *band = cairo_create(s->milky_way);
        /* A central, softly tapered band with a dark dust lane and muted
           blue/violet/rose regions. Foreground stars still animate separately. */
        for (guint32 i = 0; i < 850; i++) {
            guint32 key = hash(i + 731);
            double position = unit(key);
            double x = 0.18 + position * 0.64;
            double spread = (unit(key + 1) + unit(key + 2) + unit(key + 3) - 1.5) * 0.08;
            double lane = spread + sin(x * 17) * 0.008;
            if (fabs(lane) < 0.009 && unit(key + 4) < 0.72) continue;
            double y = 0.43 - (position - 0.5) * 0.30 + sin(position * 2 * G_PI) * 0.018 + spread;
            double taper = pow(sin(position * G_PI), 0.65);
            double alpha = (0.09 + 0.35 * exp(-spread * spread / 0.003)) * taper;
            int color = unit(key + 5) < 0.35 ? 0 : position < 0.36 ? 6 : position < 0.68 ? 7 : 8;
            glyph(s, band, i % 5 ? '.' : ':', x * width, y * height, color, alpha);
        }
        cairo_destroy(band);
    }
    cairo_set_source_surface(cr, s->milky_way, 0, 0);
    cairo_paint(cr);
}

static void streak(Surface *s, cairo_t *cr, double width, double height,
                   Flight path, double progress, int tail, char head, double alpha) {
    double x = (path.x + progress * path.dx) * width;
    double y = (path.y + progress * path.dy) * height;
    double distance = hypot(path.dx * width, path.dy * height);
    double tx = path.dx * width / distance * s->cw;
    double ty = path.dy * height / distance * s->cw;
    for (int i = tail - 1; i >= 0; i--)
        glyph(s, cr, i == 0 ? head : head == '@' && i < 5 ? '-' : '.',
            x - i * tx, y - i * ty, head == '@' && i ? 0 : 5,
            alpha * (1 - i / (double)tail));
}

static void space(Surface *s, cairo_t *cr, double width, double height, double time) {
    /* Comets traverse the upper sky for 18 seconds every four minutes. */
    double comet = event_phase(time, 240, 20, 18);
    if (comet >= 0) {
        guint32 cycle = (guint32)fmod(floor(time / 240), 4294967296.0);
        Flight path = flight(hash(s->sky_seed ^ cycle ^ 0xc04e7), TRUE);
        double fade = MIN(1, MIN(comet, 1 - comet) * 8);
        streak(s, cr, width, height, path, comet, 19, '@', fade * 0.8);
    }
    /* A twelve-second meteor shower every five minutes. */
    double shower = event_phase(time, 300, 50, 12);
    if (shower >= 0) {
        guint32 cycle = (guint32)fmod(floor(time / 300), 4294967296.0);
        guint32 seed = hash(s->sky_seed ^ cycle ^ 0x54a0e2);
        Flight direction = flight(seed, FALSE);
        for (int i = 0; i < 4; i++) {
            double clock = shower * 12 + i * 0.37;
            guint32 pass = (guint32)floor(clock / 1.5);
            Flight path = flight(hash(seed + i * 37 + pass * 1009), FALSE);
            if (path.dx * direction.dx < 0) path.x = 1 - path.x;
            path.dx = direction.dx; path.dy = direction.dy;
            double progress = fmod(clock, 1.5) / 1.5;
            streak(s, cr, width, height, path, progress, 9, '*', 1 - progress);
        }
    }
}

static void paint(Surface *s, cairo_t *cr, double width, double height, double time) {
    cairo_set_source_rgb(cr, 25.0 / 255, 25.0 / 255, 25.0 / 255);
    cairo_paint(cr);
    milky_way(s, cr, (int)width, (int)height);
    for (int i = 0; i < STARS; i++) {
        Star *star = &s->stars[i];
        double x = fmod(star->x + time * 0.00009 * (1 + i % 3), 1) * width;
        double y = fmod(star->y + time * 0.00002 * (1 + i % 2), 1) * height;
        double alpha = 0.14 + 0.48 * pow((sin(time * star->speed + star->phase) + 1) / 2, 2);
        glyph(s, cr, star->glyph, x, y, i % 9 == 0 ? 5 : 0, alpha);
    }
    space(s, cr, width, height, time);
    if (time >= s->meteor_at) {
        double age = time - s->meteor_at;
        if (age < 1.5) {
            streak(s, cr, width, height, flight(s->meteor_seed, FALSE), age / 1.5, 9, '*', 1 - age / 1.5);
        } else {
            s->meteor_at = time + g_random_double_range(8, 20);
            s->meteor_seed = g_random_int();
        }
    }
    cache_tree(s, width, height);
    double x = round((width - cairo_image_surface_get_width(s->tree)) / 2);
    /* Match the Activate Linux watermark's 48px bottom margin. */
    double y = round(height - MIN(48.0, height * 0.05) - cairo_image_surface_get_height(s->tree));
    cairo_set_source_surface(cr, s->tree, x, y);
    cairo_paint(cr);
}

static gboolean draw(GtkWidget *widget, cairo_t *cr, gpointer data) {
    paint(data, cr, gtk_widget_get_allocated_width(widget), gtk_widget_get_allocated_height(widget),
        frozen ? frozen_time : elapsed(g_get_monotonic_time(), started));
    return TRUE;
}

static void passthrough(GtkWidget *widget, gpointer unused) {
    (void)unused;
    cairo_region_t *region = cairo_region_create();
    /* Store it on the widget too: GTK reapplies this shape when mapping. */
    gtk_widget_input_shape_combine_region(widget, region);
    cairo_region_destroy(region);
}

static void free_art(Surface *s) {
    for (int i = 0; i < GLYPHS; i++) if (s->glyphs[i]) cairo_surface_destroy(s->glyphs[i]);
    if (s->tree) cairo_surface_destroy(s->tree);
    if (s->milky_way) cairo_surface_destroy(s->milky_way);
}
static void free_surface(gpointer data) {
    Surface *s = data;
    gtk_widget_destroy(s->window);
    g_object_unref(s->monitor);
    free_art(s); g_free(s);
}

static void add_monitor(GdkDisplay *display, GdkMonitor *monitor, gpointer unused) {
    (void)display; (void)unused;
    Surface *s = g_new0(Surface, 1);
    s->monitor = g_object_ref(monitor);
    s->window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
    GtkWindow *window = GTK_WINDOW(s->window);
    gtk_window_set_decorated(window, FALSE);
    gtk_window_set_accept_focus(window, FALSE);
    gtk_layer_init_for_window(window);
    gtk_layer_set_namespace(window, "dots-garden");
    gtk_layer_set_monitor(window, monitor);
    gtk_layer_set_layer(window, GTK_LAYER_SHELL_LAYER_BACKGROUND);
    gtk_layer_set_keyboard_mode(window, GTK_LAYER_SHELL_KEYBOARD_MODE_NONE);
    gtk_layer_set_exclusive_zone(window, -1);
    for (int edge = 0; edge < GTK_LAYER_SHELL_EDGE_ENTRY_NUMBER; edge++)
        gtk_layer_set_anchor(window, edge, TRUE);
    init_art(s);
    g_signal_connect(s->window, "realize", G_CALLBACK(passthrough), NULL);
    g_signal_connect(s->window, "draw", G_CALLBACK(draw), s);
    g_ptr_array_add(surfaces, s);
    gtk_widget_show_all(s->window);
}

static void remove_monitor(GdkDisplay *display, GdkMonitor *monitor, gpointer unused) {
    (void)display; (void)unused;
    for (guint i = surfaces->len; i > 0; i--) {
        Surface *s = g_ptr_array_index(surfaces, i - 1);
        if (s->monitor == monitor) g_ptr_array_remove_index(surfaces, i - 1);
    }
}

static gboolean tick(gpointer unused) {
    (void)unused;
    gint64 now = g_get_monotonic_time();
    if (!preview) tree.seconds += elapsed(now, last_tick);
    last_tick = now;
    if (!preview && elapsed(now, last_save) >= 60) {
        save_failed = !save_tree();
        last_save = now;
    }
    for (guint i = 0; i < surfaces->len; i++) {
        Surface *s = g_ptr_array_index(surfaces, i);
        gtk_widget_queue_draw(s->window);
    }
    return G_SOURCE_CONTINUE;
}
/* No periodic sources remain while frozen; Wayland can still handle display changes. */
static void mode_changed(GFileMonitor *monitor, GFile *file, GFile *other,
                         GFileMonitorEvent event, gpointer unused) {
    (void)monitor; (void)file; (void)other; (void)event; (void)unused;
    gboolean next = g_file_test(frozen_path, G_FILE_TEST_EXISTS);
    if (next == frozen) return;
    gint64 now = g_get_monotonic_time();
    /* Account for awake time on either transition, without ticking while frozen. */
    tree.seconds += elapsed(now, last_tick);
    if (next) {
        frozen_time = elapsed(now, started);
        g_source_remove(animation_timer);
        animation_timer = 0;
    } else {
        started = now - (gint64)(frozen_time * G_USEC_PER_SEC);
        animation_timer = g_timeout_add(67, tick, NULL);
    }
    save_failed = !save_tree();
    frozen = next;
    last_tick = last_save = now;
    for (guint i = 0; i < surfaces->len; i++) {
        Surface *s = g_ptr_array_index(surfaces, i);
        gtk_widget_queue_draw(s->window);
    }
}

static gboolean stop(gpointer unused) {
    (void)unused;
    gtk_main_quit();
    return G_SOURCE_REMOVE;
}

int main(int argc, char **argv) {
    preview = argc >= 3 && !strcmp(argv[1], "--preview");
    if (preview) {
        char *end;
        double hours = g_ascii_strtod(argv[2], &end);
        if (*end || !*argv[2] || !isfinite(hours) || hours < 0 || hours > 1e8 || argc > 4) return 2;
        tree = (Tree){42, 1, hours * 3600};
        char *saved = g_build_filename(g_get_user_state_dir(), "dots-garden", "state", NULL);
        Tree existing;
        if (read_tree(saved, &existing)) tree.seed = existing.seed;
        g_free(saved);
        if (argc == 4) {
            Surface s = {0}; init_art(&s);
            cairo_surface_t *png = cairo_image_surface_create(CAIRO_FORMAT_ARGB32, 1920, 1080);
            cairo_t *cr = cairo_create(png);
            paint(&s, cr, 1920, 1080, 0);
            cairo_status_t result = cairo_surface_write_to_png(png, argv[3]);
            cairo_destroy(cr); cairo_surface_destroy(png); free_art(&s);
            return result == CAIRO_STATUS_SUCCESS ? 0 : 1;
        }
    } else if (argc != 2 || strcmp(argv[1], "--run")) {
        g_printerr("Usage: renderer --run | --preview HOURS [PNG]\n"); return 2;
    }
    if (!gtk_init_check(NULL, NULL) || !gtk_layer_is_supported()) {
        g_printerr("Garden requires a Wayland desktop with layer-shell support\n"); return 1;
    }
    GFileMonitor *mode_monitor = NULL;
    if (!preview) {
        char *dir = g_build_filename(g_get_user_state_dir(), "dots-garden", NULL);
        if (g_mkdir_with_parents(dir, 0700) != 0) { g_free(dir); return 1; }
        char *lock = g_build_filename(dir, "lock", NULL);
        state_lock = open(lock, O_CREAT | O_RDWR | O_CLOEXEC, 0600);
        g_free(lock);
        if (state_lock < 0 || flock(state_lock, LOCK_EX | LOCK_NB) != 0) {
            g_printerr("Cannot lock garden state: %s\n", strerror(errno)); g_free(dir); return 1;
        }
        state_path = g_build_filename(dir, "state", NULL);
        backup_path = g_build_filename(dir, "state.bak", NULL);
        frozen_path = g_build_filename(dir, "frozen", NULL);
        g_free(dir);
        if (!load_tree()) return 1;
        GFile *marker = g_file_new_for_path(frozen_path);
        GError *error = NULL;
        mode_monitor = g_file_monitor_file(marker, G_FILE_MONITOR_NONE, NULL, &error);
        g_object_unref(marker);
        if (!mode_monitor) {
            g_printerr("Cannot watch garden mode: %s\n", error->message);
            g_error_free(error);
            return 1;
        }
        g_signal_connect(mode_monitor, "changed", G_CALLBACK(mode_changed), NULL);
        frozen = g_file_test(frozen_path, G_FILE_TEST_EXISTS);
    }
    started = last_tick = last_save = g_get_monotonic_time();
    surfaces = g_ptr_array_new_with_free_func(free_surface);
    GdkDisplay *display = gdk_display_get_default();
    g_signal_connect(display, "monitor-added", G_CALLBACK(add_monitor), NULL);
    g_signal_connect(display, "monitor-removed", G_CALLBACK(remove_monitor), NULL);
    for (int i = 0; i < gdk_display_get_n_monitors(display); i++)
        add_monitor(display, gdk_display_get_monitor(display, i), NULL);
    if (!frozen) animation_timer = g_timeout_add(67, tick, NULL);
    g_unix_signal_add(SIGTERM, stop, NULL);
    g_unix_signal_add(SIGINT, stop, NULL);
    gtk_main();
    if (animation_timer) g_source_remove(animation_timer);
    if (mode_monitor) g_object_unref(mode_monitor);
    if (!preview) {
        tree.seconds += elapsed(g_get_monotonic_time(), last_tick);
        save_failed = !save_tree();
    }
    g_ptr_array_unref(surfaces);
    if (state_lock >= 0) close(state_lock);
    g_free(state_path); g_free(backup_path); g_free(frozen_path);
    return save_failed ? 1 : 0;
}
#endif
