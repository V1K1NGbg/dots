{ lib, ... }:
{
  dconf.settings = {
    "org/nemo/compact-view" = {
      "default-zoom-level" = "standard";
    };
    "org/nemo/icon-view" = {
      captions = [ "none" "size" "date_modified" ];
      "default-zoom-level" = "small";
      "labels-beside-icons" = false;
    };
    "org/nemo/preferences" = {
      "bulk-rename-tool" = lib.hm.gvariant.mkArray
        lib.hm.gvariant.type.uchar
        (map lib.hm.gvariant.mkUchar [ 98 117 108 107 121 ]);
      "click-double-parent-folder" = true;
      "close-device-view-on-device-eject" = true;
      "date-font-choice" = "no-mono";
      "date-format" = "iso";
      "default-folder-viewer" = "list-view";
      "ignore-view-metadata" = true;
      "inherit-folder-viewer" = true;
      "show-advanced-permissions" = true;
      "show-compact-view-icon-toolbar" = false;
      "show-directory-item-counts" = "local-only";
      "show-edit-icon-toolbar" = false;
      "show-full-path-titles" = true;
      "show-hidden-files" = true;
      "show-home-icon-toolbar" = false;
      "show-location-entry" = true;
      "show-new-folder-icon-toolbar" = false;
      "show-next-icon-toolbar" = false;
      "show-open-in-terminal-toolbar" = false;
      "show-previous-icon-toolbar" = false;
      "show-reload-icon-toolbar" = false;
      "show-search-icon-toolbar" = true;
      "show-show-thumbnails-toolbar" = false;
      "show-up-icon-toolbar" = false;
      "size-prefixes" = "base-10";
      "start-with-dual-pane" = false;
      "thumbnail-limit" = lib.hm.gvariant.mkUint64 10485760;
      "tooltips-in-icon-view" = false;
      "tooltips-in-list-view" = false;
      "tooltips-on-desktop" = false;
      "tooltips-show-file-type" = false;
    };
    "org/nemo/list-view" = {
      "default-column-order" = [
        "name"
        "size"
        "type"
        "detailed_type"
        "owner"
        "permissions"
        "date_modified"
        "date_created_with_time"
        "date_accessed"
        "date_created"
        "group"
        "where"
        "mime_type"
        "date_modified_with_time"
        "octal_permissions"
      ];
      "default-visible-columns" = [
        "name"
        "size"
        "type"
        "detailed_type"
        "owner"
        "permissions"
        "date_modified"
      ];
      "default-zoom-level" = "small";
    };
    "org/nemo/preferences/menu-config" = {
      "background-menu-open-as-root" = false;
    };
    "org/nemo/sidebar-panels/tree" = {
      "show-only-directories" = false;
    };
    "org/nemo/window-state" = {
      "devices-expanded" = true;
      geometry = "1257x1357+13+32";
      maximized = false;
      "my-computer-expanded" = true;
      "network-expanded" = true;
      "side-pane-view" = "places";
      "sidebar-bookmark-breakpoint" = 0;
      "start-with-sidebar" = true;
      "start-with-toolbar" = false;
    };
  };
}
