local DataStorage = require("datastorage")
local SQ3 = require("lua-ljsqlite3/init")
local datetime = require("datetime")

local db_location = DataStorage:getSettingsDir() .. "/statistics.sqlite3"

local DataGatherer = {}

function DataGatherer:getPerPageDurations(id_book, max_sec)
    local conn = SQ3.open(db_location)
    local sql = string.format([[
        SELECT page, min(sum(duration), %d) AS dur
        FROM page_stat
        WHERE id_book = %d
        GROUP BY page
        ORDER BY page;
    ]], max_sec, id_book)

    local pages = {}
    local capped_count = 0
    local stmt = conn:prepare(sql)
    if stmt then
        while true do
            local row = stmt:step()
            if not row then break end
            local dur = tonumber(row[2]) or 0
            local is_capped = dur >= max_sec
            if is_capped then
                capped_count = capped_count + 1
            end
            table.insert(pages, {
                page = tonumber(row[1]),
                duration = dur,
                capped = is_capped,
            })
        end
        stmt:close()
    end
    conn:close()
    return pages, capped_count
end

function DataGatherer:mergeVolatilePages(db_pages, page_stat, max_sec)
    local page_index = {}
    for i, entry in ipairs(db_pages) do
        page_index[entry.page] = i
    end

    for page_num, tuples in pairs(page_stat) do
        local total = 0
        for _, tuple in ipairs(tuples) do
            total = total + (tuple[2] or 0)
        end
        local capped_dur = math.min(total, max_sec)
        local is_capped = capped_dur >= max_sec

        local idx = page_index[page_num]
        if idx then
            if capped_dur > db_pages[idx].duration then
                db_pages[idx].duration = capped_dur
                db_pages[idx].capped = is_capped
                db_pages[idx].is_session = true
            end
        else
            table.insert(db_pages, {
                page = page_num,
                duration = capped_dur,
                capped = is_capped,
                is_session = true,
            })
        end
    end

    table.sort(db_pages, function(a, b) return a.page < b.page end)
    return db_pages
end

function DataGatherer:markSessionPages(db_pages, page_stat)
    for _, entry in ipairs(db_pages) do
        if page_stat[entry.page] then
            entry.is_session = true
        end
    end
end

function DataGatherer:getCurrentPageDwell(page_stat, curr_page)
    local tuples = page_stat and page_stat[curr_page]
    if not tuples or #tuples == 0 then return nil end
    local last_tuple = tuples[#tuples]
    local timestamp = last_tuple[1]
    local accumulated = last_tuple[2] or 0
    if accumulated == 0 and timestamp then
        return os.time() - timestamp
    end
    return accumulated
end

function DataGatherer:getSessionStartPage(page_stat)
    local min_page = nil
    for page_num, _ in pairs(page_stat) do
        if not min_page or page_num < min_page then
            min_page = page_num
        end
    end
    return min_page
end

function DataGatherer:collect(ui)
    local stats = ui.statistics
    local doc = ui.document
    local toc = ui.toc

    local data = {}

    data.avg_time = stats.avg_time or 0
    data.has_data = stats.avg_time ~= nil and (stats.book_read_pages + stats.mem_read_pages) > 0

    local curr_page = ui:getCurrentPage()
    data.curr_page = curr_page
    data.total_pages = doc:getPageCount()
    data.pages_left_book = doc:getTotalPagesLeft(curr_page)
    data.pages_left_chapter = toc:getChapterPagesLeft(curr_page) or data.pages_left_book

    local user_duration_format = G_reader_settings:readSetting("duration_format", "classic")
    data.duration_format = user_duration_format
    data.time_left_book = data.pages_left_book * data.avg_time
    data.time_left_chapter = data.pages_left_chapter * data.avg_time

    data.book_read_pages = stats.book_read_pages or 0
    data.book_read_time = stats.book_read_time or 0
    data.mem_read_pages = stats.mem_read_pages or 0
    data.mem_read_time = stats.mem_read_time or 0
    data.total_read_pages = data.book_read_pages + data.mem_read_pages
    data.total_read_time = data.book_read_time + data.mem_read_time

    data.min_sec = stats.settings.min_sec
    data.max_sec = stats.settings.max_sec

    local db_pages, capped_count = self:getPerPageDurations(stats.id_curr_book, data.max_sec)
    self:markSessionPages(db_pages, stats.page_stat)
    db_pages = self:mergeVolatilePages(db_pages, stats.page_stat, data.max_sec)
    data.per_page = db_pages
    data.capped_count = capped_count

    data.session_start_page = self:getSessionStartPage(stats.page_stat)

    data.current_page_dwell = self:getCurrentPageDwell(stats.page_stat, stats.curr_page)

    return data
end

return DataGatherer
