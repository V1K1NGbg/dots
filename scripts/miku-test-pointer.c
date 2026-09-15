#include <wayland-client.h>
#include <stdio.h>
#include <string.h>
#include <time.h>
// wlr-virtual-pointer v1 requests, per swaywm/wlr-protocols.
// Only the test needs this protocol; the companion has no global input listener.
static const struct wl_message pointer_requests[] = {
    {"motion", "uff", NULL}, {"motion_absolute", "uuuuu", NULL},
    {"button", "uuu", NULL}, {"axis", "uuf", NULL}, {"frame", "", NULL},
    {"axis_source", "u", NULL}, {"axis_stop", "uu", NULL},
    {"axis_discrete", "uufi", NULL}, {"destroy", "", NULL}
};
static const struct wl_interface pointer_interface = {
    "zwlr_virtual_pointer_v1", 1, 9, pointer_requests, 0, NULL
};
static const struct wl_interface *create_types[] = {&wl_seat_interface, &pointer_interface};
static const struct wl_message manager_requests[] = {
    {"create_virtual_pointer", "?on", create_types}, {"destroy", "", NULL}
};
static const struct wl_interface manager_interface = {
    "zwlr_virtual_pointer_manager_v1", 1, 2, manager_requests, 0, NULL
};
static struct wl_proxy *manager;
static void global(void *d, struct wl_registry *r, uint32_t n, const char *i, uint32_t v) {
    if (!strcmp(i, "zwlr_virtual_pointer_manager_v1")) manager=wl_registry_bind(r,n,&manager_interface,1);
}
static void removed(void *d, struct wl_registry *r, uint32_t n) {}
int main(void) {
    struct wl_display *d=wl_display_connect(NULL);
    if (!d) return 1;
    struct wl_registry *r=wl_display_get_registry(d);
    struct wl_registry_listener listener={global,removed};
    wl_registry_add_listener(r,&listener,NULL); wl_display_roundtrip(d);
    if (!manager) return 2;
    struct wl_proxy *p=wl_proxy_marshal_constructor(manager,0,&pointer_interface,NULL,NULL);
    char line[128]; unsigned x,y,w,h;
    while (fgets(line,sizeof line,stdin)) {
        struct timespec t; clock_gettime(CLOCK_MONOTONIC,&t);
        uint32_t ms=t.tv_sec*1000+t.tv_nsec/1000000;
        if (sscanf(line,"m %u %u %u %u",&x,&y,&w,&h)==4) wl_proxy_marshal(p,1,ms,x,y,w,h);
        else if (sscanf(line,"b %u",&x)==1) wl_proxy_marshal(p,2,ms,272,x);
        wl_proxy_marshal(p,4); wl_display_roundtrip(d);
        puts("ok"); fflush(stdout);
    }
    wl_proxy_marshal(p,2,0,272,0); wl_proxy_marshal(p,4);
    wl_proxy_marshal(p,8); wl_proxy_destroy(p); wl_display_roundtrip(d); wl_display_disconnect(d);
}
