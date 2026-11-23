# @name Pool & Spa Monitor
# @desc Live pool & spa display with heating and chiller states
# @author Assistant
# @version 3.1

import json

class PoolSpaMonitor
    var pool_temp
    var pool_target
    var pool_pump
    var pool_heat
    var pool_chiller

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
        self.pool_chiller = false

        self.spa_temp = 98
        self.spa_target = 100
        self.spa_pump = false
        self.spa_heat = false

        # Bitmaps for 0-9, degree, arrow, dash, space, letters C, H, I, L (3 columns x 5 rows)
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
            ' ': [0x00, 0x00, 0x00],
            'C': [0x1F, 0x11, 0x11],
            'H': [0x1F, 0x04, 0x1F],
            'I': [0x00, 0x1F, 0x00],
            'L': [0x1F, 0x10, 0x10],
            'O': [0x1F, 0x11, 0x1F],
            'N': [0x1F, 0x06, 0x1F]
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
            if data.find("pool_chiller") != nil self.pool_chiller = bool(data["pool_chiller"]) end

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
        if (self.pool_pump && (self.pool_heat || self.pool_chiller)) || (self.spa_pump && self.spa_heat)
            return 12000
        end
        return 7000
    end

    def draw()
        clear()

        var ORANGE = 0xFF7700
        var BLUE   = 0x00B4D8
        var CYAN   = 0x00E5FF
        var WHITE  = 0xFFFFFF
        var GRAY   = 0x777777

        # 1. Both pumps off
        if !self.pool_pump && !self.spa_pump
            if height() >= 16
                text(1, 6, "POOL PUMP", GRAY)
                text(1, 14, "OFF", GRAY)
            else
                text(1, 6, "PUMP OFF", GRAY)
            end
            return
        end

        # Spa takes priority if running, otherwise Pool
        var is_spa = self.spa_pump
        var name = is_spa ? "Spa:" : "Pool:"
        var cur_temp = is_spa ? self.spa_temp : self.pool_temp
        var target_temp = is_spa ? self.spa_target : self.pool_target
        var is_heating = is_spa ? self.spa_heat : self.pool_heat
        var is_chilling = !is_spa && self.pool_pump && self.pool_chiller

        var cur_color = (cur_temp >= target_temp) ? ORANGE : BLUE

        # -------------------------------------------------------------
        # Case A: TALL DISPLAY (TC002, 52x16)
        # -------------------------------------------------------------
        if height() >= 16
            if is_chilling
                # Chiller is ON: Line 1 = "Pool: [cur]°", Line 2 = "Chiller on"
                text(1, 6, "Pool: " + str(cur_temp) + "°", CYAN)
                text(1, 14, "Chiller on", CYAN)
            elif is_heating
                # Heater is ON: Line 1 = "Pool:" / "Spa:", Line 2 = "[cur]° -> [target]°"
                text(1, 6, name, WHITE)
                var x1 = 1
                text(x1, 14, str(cur_temp) + "°", cur_color)
                var x2 = x1 + (cur_temp >= 100 ? 18 : 14)
                text(x2, 14, "->", WHITE)
                var x3 = x2 + 12
                text(x3, 14, str(target_temp) + "°", ORANGE)
            else
                # Heater & Chiller are OFF: keep temperature on the SAME line as text
                text(1, 10, (is_spa ? "Spa: " : "Pool: ") + str(cur_temp) + "°", BLUE)
            end
            return
        end

        # -------------------------------------------------------------
        # Case B: STANDARD MATRIX DISPLAY (32x8)
        # -------------------------------------------------------------
        if is_chilling
            # Chiller is ON on 32x8:
            # Top row: "POOL: [temp]°"
            # Bottom row (rows 3-7): "CHILL ON"
            text(1, 3, "P:" + str(cur_temp) + "°", CYAN)
            pixel(30, 1, CYAN) # Cyan chiller indicator dot on top right
            self.draw_tiny(1, 3, "CHILL ON", CYAN)

        elif is_heating
            # Heater is ON on 32x8:
            # Top row: "POOL" or "SPA" + heating dot
            text(1, 3, is_spa ? "SPA" : "POOL", WHITE)
            pixel(30, 1, ORANGE)

            # Bottom row (rows 3-7): 3x5 font "[cur]°->[target]°"
            var nx = self.draw_tiny(1, 3, str(cur_temp) + "°", cur_color)
            nx = self.draw_tiny(nx, 3, "->", WHITE)
            self.draw_tiny(nx, 3, str(target_temp) + "°", ORANGE)

        else
            # Heater & Chiller are OFF:
            # Keep on the SAME single line: "Pool 62°" or "Spa 98°"
            text(1, 6, is_spa ? "Spa" : "Pool", WHITE)
            var temp_x = is_spa ? 16 : 20
            text(temp_x, 6, str(cur_temp) + "°", BLUE)
        end
    end
end

return PoolSpaMonitor()
