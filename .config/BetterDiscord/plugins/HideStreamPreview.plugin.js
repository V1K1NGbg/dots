/**
 * @name HideStreamPreview
 * @author blurrpy
 * @description Hide your own stream preview in multistream calls.
 * @version 0.0.5
 * @authorLink https://github.com/danegottwald
 * @website https://github.com/danegottwald
 * @donate https://www.paypal.com/paypalme/danegottwald
 * @source https://raw.githubusercontent.com/danegottwald/BetterDiscordPlugins/main/HideStreamPreview/HideStreamPreview.plugin.js
 */

const fs = require("fs");
const path = require("path");
const request = require("request");

const config = {
    "info": {
        "name": "HideStreamPreview",
        "authors": [{
            "name": "blurrpy",
            "discord_id": "154401402263699457",
            "github_username": "danegottwald"
        }],
        "version": "0.0.5",
        "description": "Hide your own stream preview when screen sharing with multiple users",
        "github": "https://github.com/danegottwald",
        "github_raw": "https://raw.githubusercontent.com/danegottwald/BetterDiscordPlugins/main/HideStreamPreview/HideStreamPreview.plugin.js"
    },
    "changelog": [
        { "title": "Updates!", "items": ["Removed deprecated DiscordAPI use", "Bug fixes"] },
    ],
    "main": "HideStreamPreview.js"
};

var settings = {
    "showWhenLowStreams": {
        "title": "Show Own Stream At Low Stream Count (1-2 streams)",
        "description": "Display stream preview until 3 streams are active",
        "value": true
    }
}

module.exports = !global.ZeresPluginLibrary ? class {
    constructor() {
        this._config = config;
    }

    load() {
        BdApi.showConfirmationModal("Library plugin is needed",
            `ZeresPluginLibrary is missing. Please click Download Now to install it.`, {
            confirmText: "Download",
            cancelText: "Cancel",
            onConfirm: () => {
                request.get("https://rauenzi.github.io/BDPluginLibrary/release/0PluginLibrary.plugin.js", (error, response, body) => {
                    if (error) {
                        return electron.shell.openExternal("https://github.com/rauenzi/BDPluginLibrary");
                    }
                    fs.writeFileSync(path.join(BdApi.Plugins.folder, "0PluginLibrary.plugin.js"), body);
                });
            }
        });
    }

    start() { }

    stop() { }

} : (([Plugin, Library]) => {
    const {
        DiscordModules: { GuildStore, SelectedGuildStore, SelectedChannelStore, StreamStore, UserNameResolver, UserStore, GuildMemberStore },
        Settings,
        PluginUpdater,
        PluginUtilities,
    } = Library;

    return class HideStreamPreview extends Plugin {
        load() {
        }

        unload() {
        }

        onStart() {
            // Check for Plugin Updates
            PluginUpdater.checkForUpdate(this.getName(), this.getVersion(), "https://raw.githubusercontent.com/danegottwald/BetterDiscordPlugins/main/HideStreamPreview/HideStreamPreview.plugin.js");

            // Load Settings from Config on Startup
            Object.entries(PluginUtilities.loadData("HideStreamPreview", "settings", {})).forEach(([setting, value]) => {
                settings[setting]["value"] = value
            });
        }

        onStop() {
        }

        getSettingsPanel() {
            // Dynamically create settings panel depending on the keys in the 'settings' dictionary
            var panel = new Settings.SettingPanel();
            Object.entries(settings).forEach(([setting, content]) => {
                panel.append(
                    new Settings.Switch(
                        content["title"], content["description"], content["value"],
                        (val) => {
                            settings[setting]["value"] = val;
                            PluginUtilities.saveSettings("HideStreamPreview", { [setting]: val });
                        }
                    )
                );
            });

            return panel.getElement();
        }

        // Hide stream preview when the wrapper for the video tiles is targeted
        observer(e) {
            if (e.target.tagName == "DIV" && e.target.className.includes("previewWrapper")) {
                this._hideStreamPreview();
            }
        }

        _grabGuildId() {
            // Use regex pattern to match and capture the ID from channel links
            const pattern = /\/channels\/(\d+)/;
            
            // Find first correct link element
            let linkElement = Array.from(document.getElementsByTagName("a")).find(a => (a.href.match(pattern)))

            if (linkElement) {
                return linkElement.href.match(pattern)[1];
            } else {
                console.error("Unable to grab guild ID, attempting to continue")
            }
        }

        _hideStreamPreview() {
            // Use UserStore to get the current user ID and information
            const currentUser = UserStore.getCurrentUser();
            
            // Check if currentUser is valid
            if (!currentUser) {
                console.error('Unable to get current user information, attempting to continue');
            }
            
            const userId = currentUser.id;
            const username = currentUser.username;

            // Use GuildMemberStore to get the current users nickname in the guild/server
            const nickname = GuildMemberStore.getNick(this._grabGuildId(), userId)
            if (!nickname) {
                console.error('Unable to get current user nickname, attempting to continue');
            }
        
            // Only hide stream preview if there are three or more streams OR if setting is false
            if (!settings["showWhenLowStreams"]["value"] || StreamStore.getAllActiveStreams().length >= 3) {
                // Grab the 'span' element that refers to the current user or current nick
                let element = Array.from(document.getElementsByTagName('span')).find(span => ((span.textContent.toLowerCase() == username || span.textContent == nickname) && span.className.includes("overlayTitleText"))
            );
                
                // Locate the parent div container for the stream tile
                // As of July 25 2024 this div container is 8 parents away
                const numParents = 8;
                for (let i = 0; i < numParents; i++) {
                    element = element.parentElement;
                }
        
                // Hide the element if it exists
                if (element != null) {
                    element.style.display = "none";
                }
            }
        }
        

    };

})(global.ZeresPluginLibrary.buildPlugin(config));
