local BD = require("ui/bidi")
local Blitbuffer = require("ffi/blitbuffer")
local Geom = require("ui/geometry")
local Math = require("optmath")
local Widget = require("ui/widget/widget")

local SpeedHistogramWidget = Widget:extend{
    width = nil,
    height = nil,
    per_page = nil,
    max_sec = 120,
    avg_time = nil,
    session_start_page = nil,
    total_pages = nil,

    color_historical = Blitbuffer.COLOR_DARK_GRAY,
    color_session = Blitbuffer.COLOR_GRAY,
    color_capped = Blitbuffer.COLOR_BLACK,
    color_avg_line = Blitbuffer.COLOR_BLACK,
    color_session_marker = Blitbuffer.COLOR_BLACK,
    color_background = Blitbuffer.COLOR_WHITE,
}

function SpeedHistogramWidget:init()
    self.dimen = Geom:new{ w = self.width, h = self.height }

    self.page_lookup = {}
    for _, entry in ipairs(self.per_page) do
        self.page_lookup[entry.page] = entry
    end

    self.max_duration = self.max_sec
    for _, entry in ipairs(self.per_page) do
        if entry.duration > self.max_duration then
            self.max_duration = entry.duration
        end
    end

    self.bucket_size = 1
    if self.total_pages > self.width then
        self.bucket_size = math.ceil(self.total_pages / self.width)
    end
    self.num_bars = math.ceil(self.total_pages / self.bucket_size)

    local bar_w = math.floor(self.width / self.num_bars)
    local remainder = self.width - self.num_bars * bar_w
    self.bar_widths = {}
    for n = 1, self.num_bars do
        local w = bar_w
        if remainder > 0 and n % math.max(1, math.floor(self.num_bars / remainder)) == 0 then
            w = w + 1
            remainder = remainder - 1
        end
        self.bar_widths[n] = w
    end

    self.buckets = {}
    for b = 1, self.num_bars do
        local page_start = (b - 1) * self.bucket_size + 1
        local page_end = math.min(b * self.bucket_size, self.total_pages)

        local total_dur = 0
        local count = 0
        local has_session = false
        local has_capped = false

        for p = page_start, page_end do
            local entry = self.page_lookup[p]
            if entry then
                total_dur = total_dur + entry.duration
                count = count + 1
                if entry.is_session then has_session = true end
                if entry.capped then has_capped = true end
            end
        end

        local avg_dur = count > 0 and (total_dur / count) or 0
        self.buckets[b] = {
            duration = avg_dur,
            has_data = count > 0,
            has_session = has_session,
            has_capped = has_capped,
            page_start = page_start,
            page_end = page_end,
        }
    end

    if BD.mirroredUILayout() then
        self.do_mirror = true
    end
end

function SpeedHistogramWidget:paintTo(bb, x, y)
    bb:paintRect(x, y, self.width, self.height, self.color_background)

    local bar_x = 0
    for n = 1, self.num_bars do
        local idx = self.do_mirror and (self.num_bars - n + 1) or n
        local bucket = self.buckets[idx]
        local bar_w = self.bar_widths[idx]

        if bucket.has_data then
            local ratio = math.min(bucket.duration / self.max_duration, 1)
            local bar_h = Math.round(ratio * self.height)
            if bar_h == 0 and bucket.duration > 0 then
                bar_h = 1
            end
            local bar_y = self.height - bar_h

            local color
            if bucket.has_capped then
                color = self.color_capped
            elseif bucket.has_session then
                color = self.color_session
            else
                color = self.color_historical
            end

            bb:paintRect(x + bar_x, y + bar_y, bar_w, bar_h, color)
        end

        if self.session_start_page
                and bucket.page_start <= self.session_start_page
                and bucket.page_end >= self.session_start_page then
            bb:paintRect(x + bar_x, y, 1, self.height, self.color_session_marker)
        end

        bar_x = bar_x + bar_w
    end

    if self.avg_time and self.avg_time > 0 then
        local avg_ratio = math.min(self.avg_time / self.max_duration, 1)
        local avg_y = y + self.height - Math.round(avg_ratio * self.height)
        local dash_len = 4
        local gap_len = 4
        local lx = x
        local drawing = true
        while lx < x + self.width do
            if drawing then
                local seg_w = math.min(dash_len, x + self.width - lx)
                bb:paintRect(lx, avg_y, seg_w, 1, self.color_avg_line)
            end
            lx = lx + (drawing and dash_len or gap_len)
            drawing = not drawing
        end
    end
end

return SpeedHistogramWidget
