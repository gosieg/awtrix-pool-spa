# @name Pool & Spa Monitor
# @desc Static 2-line pool & spa display without scrolling
# @author Assistant
# @version 3.0

import json

class PoolSpaMonitor
    var pool_temp
    var pool_target
    var pool_pump
    var pool_heat

    var spa_temp
    var spa_target
    var spa_pump
    var spa_heat

    # Built-in 3x5 bitmap font for crisp two-line display on 8-pixel panels
    var font3x5

    def init()
        self.pool_temp = 62
        self.pool_target = 86
        self.pool_pump = false
        self.pool_heat = false

        self.spa_temp = 98
        self.spa_target = 100
        self.spa_pump = false
        self.spa_heat = false

        # Bitmaps for 0-9, degree, arrow, dash, space (3 columns x 5 rows)
        self.font3x5 = {
            '0': [0x1F, 0x11, 0x1F],
            '1': [0x00, 0x1F, 0x00],
            '2': [0x1D, 0x15, 0x17],
            '3': [0x15, 0x15, 0x1F],
            '4': [0x07, 0x04, 0x1F],
            '5': [0x17, 0x15, 0x1D],
            '6': [0x1F, 0x15, 0x1D],
            '7': [0x01, 0x01, 0x1F],
            '8': [0x1F, 0x15, 0x1F],
            '9': [0x17, 0x15, 0x1F],
            '°': [0x03, 0x03, 0x00],
            '-': [0x04, 0x04, 0x04],
            '>': [0x11, 0x0A, 0x04],
            ' ': [0x00, 0x00, 0x00]
        }
    end

    def setup()
        mqtt.subscribe("awtrix/pool_spa", def (topic, payload)
            var data = json.load(payload)
            if data == nil || !isinstance(data, map) return end

            if data.find("pool") != nil self.pool_temp = int(data["pool"]) end
            if data.find("pool_target") != nil self.pool_target = int(data["pool_target"]) end
            if data.find("pool_pump") != nil self.pool_pump = bool(data["pool_pump"]) end
            if data.find("pool_heat") != nil self.pool_heat = bool(data["pool_heat"]) end

            if data.find("spa") != nil self.spa_temp = int(data["spa"]) end
            if data.find("spa_target") != nil self.spa_target = int(data["spa_target"]) end
            if data.find("spa_pump") != nil self.spa_pump = bool(data["spa_pump"]) end
            if data.find("spa_heat") != nil self.spa_heat = bool(data["spa_heat"]) end
        end)
    end

    # Helper to draw a string with 3x5 pixel font at (x, y)
    def draw_tiny(x, y, s, col)
        var cur_x = x
        for i: 0 .. (size(s) - 1)
            var ch = s[i]
            var glyph = self.font3x5.find(ch)
            if glyph != nil
                for col_idx: 0 .. 2
                    var col_bits = glyph[col_idx]
                    for row_idx: 0 .. 4
                        if (col_bits & (1 << row_idx)) != 0
                            pixel(cur_x + col_idx, y + row_idx, col)
                        end
                    end
                end
                cur_x += 4 # 3 pixels width + 1 pixel spacing
            else
                cur_x += 2
            end
        end
        return cur_x
    end

    def duration()
        if (self.pool_pump && self.pool_heat) || (self.spa_pump && self.spa_heat)
            return 12000
        end
        return 7000
    end

    def draw()
        clear()

        var ORANGE = 0xFF7700
        var BLUE   = 0x00B4D8
        var WHITE  = 0xFFFFFF
        var GRAY   = 0x777777

        # 1. Both pumps off
        if !self.pool_pump && !self.spa_pump
            if height() >= 16
                text(1, 6, "POOL PUMP", GRAY)
                text(1, 14, "OFF", GRAY)
            else
                # Single screen static alert
                text(1, 6, "PUMP OFF", GRAY)
            end
            return
        end

        # Decide which body of water is active (Spa takes visual priority if running)
        var name = self.spa_pump ? "Spa:" : "Pool:"
        var cur_temp = self.spa_pump ? self.spa_temp : self.pool_temp
        var target_temp = self.spa_pump ? self.spa_target : self.pool_target
        var is_heating = self.spa_pump ? self.spa_heat : self.pool_heat

        var cur_color = (cur_temp >= target_temp) ? ORANGE : BLUE

        # -------------------------------------------------------------
        # Case A: TALL DISPLAY (TC002, 52x16)
        # -------------------------------------------------------------
        if height() >= 16
            # Line 1: Header ("Pool:" or "Spa:")
            text(1, 6, name, WHITE)

            # Line 2: Temperatures
            if is_heating
                # Line 2: "[cur]° -> [target]°"
                var x1 = 1
                text(x1, 14, str(cur_temp) + "°", cur_color)
                var x2 = x1 + (cur_temp >= 100 ? 18 : 14)
                text(x2, 14, "->", WHITE)
                var x3 = x2 + 12
                text(x3, 14, str(target_temp) + "°", ORANGE)
            else
                # Line 2: "temp [cur]°"
                text(1, 14, str(cur_temp) + "°", BLUE)
            end
            return
        end

        # -------------------------------------------------------------
        # Case B: STANDARD MATRIX DISPLAY (32x8)
        # -------------------------------------------------------------
        if is_heating
            # Top row (Rows 0-1): Title and heating indicator
            if name == "Spa:"
                text(1, 3, "SPA", WHITE)
            else
                text(1, 3, "POOL", WHITE)
            end
            # Subtle heating indicator dot on top right
            pixel(30, 1, ORANGE)

            # Bottom row (Rows 3-7): 3x5 font "[cur]°->[target]°"
            # Fits in ~26 columns across row y=3 without scrolling!
            var nx = self.draw_tiny(1, 3, str(cur_temp) + "°", cur_color)
            nx = self.draw_tiny(nx, 3, "->", WHITE)
            self.draw_tiny(nx, 3, str(target_temp) + "°", ORANGE)
        else
            # Not heating:
            # Displays "[Pool|Spa] [temp]°" cleanly on a single static line (fits in 24-28px)
            text(1, 6, self.spa_pump ? "Spa" : "Pool", WHITE)
            var temp_x = self.spa_pump ? 16 : 20
            text(temp_x, 6, str(cur_temp) + "°", BLUE)
        end
    end
end

return PoolSpaMonitor()
