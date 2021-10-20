---@private
---@param isInterval number
---@param period number float
---@param callFunc fun(curTimer:Timer):Timer
---@param title string
---@return Timer
function Timer(isInterval, period, callFunc, title)
    if (period == nil or type(isInterval) ~= "boolean" or type(callFunc) ~= "function") then
        return
    end

    ---@class Timer
    local this = {}

    ---@private
    this.__NAME__ = "Timer"
    ---@private
    this.__ID__ = "T:" .. htime.inc .. string.random(5)

    ---@private
    this.__PROPERTIES__ = {
        kernel = nil,
        pause = nil,
        callFunc = callFunc,
        isInterval = isInterval,
        period = period,
        title = title or "",
    }
    this.remain = function(fluctuate)
        local remain = this.__PROPERTIES__.pause or (this.__PROPERTIES__.kernel - htime.inc)
        if (type(fluctuate) == "number") then
            if (htime.kernel[this.__PROPERTIES__.kernel] and htime.kernel[this.__PROPERTIES__.kernel].keyExists(this.__ID__)) then
                remain = remain + fluctuate
                htime.kernel[this.__PROPERTIES__.kernel].splice(this.__ID__)
                htime.penetrate(this, remain)
            end
            return this
        end
        return math.max(0, remain / 100)
    end
    this.period = function(fluctuate)
        if (type(fluctuate) == "number") then
            this.__PROPERTIES__.period = this.__PROPERTIES__.period + fluctuate
            if (this.remain() > this.__PROPERTIES__.period) then
                htime.kernel[this.__PROPERTIES__.kernel].splice(this.__ID__)
                htime.penetrate(this, this.__PROPERTIES__.period * 100)
            end
            return this
        end
        return this.__PROPERTIES__.period
    end
    this.elapsed = function()
        return math.max(0, this.period() - this.remain())
    end
    this.title = function(modify)
        if (type(modify) == "string") then
            this.__PROPERTIES__.title = modify
            return this
        end
        return this.__PROPERTIES__.title
    end
    this.pause = function()
        local k = this.__PROPERTIES__.kernel or 0
        if (k > htime.inc) then
            htime.kernel[k].splice(this.__ID__)
            this.__PROPERTIES__.pause = k - htime.inc
        end
        return this
    end
    this.resume = function()
        if (this.__PROPERTIES__.pause ~= nil) then
            htime.penetrate(this, this.__PROPERTIES__.pause / 100)
            this.__PROPERTIES__.pause = nil
        end
        return this
    end
    this.destroy = function()
        local k = this.__PROPERTIES__.kernel or 0
        if (k > htime.inc) then
            htime.kernel[k].splice(this.__ID__)
        end
        this.__PROPERTIES__.pause = nil
        this.__PROPERTIES__.kernel = nil
        return this
    end
    return this
end

---@class htime
htime = htime or {}

if (DEBUGGING) then
    htime.debug = htime.debug or {}
end

htime.inc = htime.inc or 0 --- 获取开始游戏后经过的总秒数
htime.hour = htime.hour or 0 --- 时
htime.min = htime.min or 0 --- 分
htime.sec = htime.sec or 0 --- 秒
htime.msec = htime.msec or 0 --- 毫秒
---@type Array[]
htime.kernel = htime.kernel or {} --- 内核

---@param t Timer
---@param remain number msec
---@private
function htime.penetrate(t, remain)
    remain = remain or t.__PROPERTIES__.period
    local i = math.ceil(htime.inc + math.max(1, remain * 100))
    if (htime.kernel[i] == nil) then
        htime.kernel[i] = Array()
    end
    t.__PROPERTIES__.kernel = i
    if (htime.debug ~= nil and false == table.includes(htime.debug, i)) then
        table.insert(htime.debug, i)
    end
    htime.kernel[i].push(t, t.__ID__)
end

--- 系统时钟
---@private
function htime.clock()
    htime.inc = htime.inc + 1
    -- timer
    htime.msec = htime.msec + 10
    if (htime.msec >= 1000) then
        htime.msec = 0
        htime.sec = htime.sec + 1
        if (htime.sec >= 60) then
            htime.sec = 0
            htime.min = htime.min + 1
            if (htime.min >= 60) then
                htime.min = 0
                htime.hour = htime.hour + 1
            end
        end
    end
    -- trigger
    local inc = math.floor(htime.inc)
    if (htime.kernel[inc] ~= nil) then
        ---@param t Timer
        htime.kernel[inc].forEach(function(_, t)
            local status, sErr = xpcall(t.__PROPERTIES__.callFunc, debug.traceback, t)
            if (status == true) then
                if (t.__PROPERTIES__.isInterval) then
                    if (t.__PROPERTIES__.kernel ~= nil) then
                        htime.penetrate(t)
                    end
                else
                    t.destroy()
                end
            else
                --执行出错时打印错误
                print(sErr)
            end
        end)
        htime.kernel[inc] = nil
        if (htime.debug ~= nil) then
            table.delete(htime.debug, inc)
        end
    end
end

--- 从内核中获取一个Timer对象
---@param period number sec
---@private
function htime.periodic(isInterval, period, callFunc, title)
    ---@type Timer
    local t = Timer(isInterval, period, callFunc, title)
    if (t ~= nil) then
        htime.penetrate(t)
    end
    return t
end

--- 魔兽小时[0.00-24.00]
function htime.timeOfDay(modify)
    if (type(modify) == "number") then
        cj.SetFloatGameState(GAME_STATE_TIME_OF_DAY, modify)
    end
    return cj.GetFloatGameState(GAME_STATE_TIME_OF_DAY)
end

--- 魔兽小时流逝速度[默认1.00]
function htime.timeOfDayScale(modify)
    if (type(modify) == "number") then
        cj.SetTimeOfDayScale(modify)
    end
    return cj.GetTimeOfDayScale()
end

--- 是否夜晚
---@return boolean
function htime.isNight()
    return (htime.timeOfDay() <= 6.00 or htime.timeOfDay() >= 18.00)
end

--- 是否白天
---@return boolean
function htime.isDay()
    return (htime.timeOfDay() > 6.00 and htime.timeOfDay() < 18.00)
end

-- 设置一次性计时器
---@param period number
---@param callFunc fun(curTimer:Timer):void
---@param title string
---@return Timer
function htime.setTimeout(period, callFunc, title)
    return htime.periodic(false, period, callFunc, title)
end

--- 设置周期性计时器
---@param period number
---@param callFunc fun(curTimer:Timer):void
---@param title string
---@return Timer
function htime.setInterval(period, callFunc, title)
    return htime.periodic(true, period, callFunc, title)
end

--- 获取过去的时分秒
---@return string HH:ii:ss
function htime.gone()
    local str = ""
    if (htime.hour < 10) then
        str = str .. "0" .. htime.hour
    else
        str = str .. htime.hour
    end
    str = str .. ":"
    if (htime.min < 10) then
        str = str .. "0" .. htime.min
    else
        str = str .. htime.min
    end
    str = str .. ":"
    if (htime.sec < 10) then
        str = str .. "0" .. htime.sec
    else
        str = str .. htime.sec
    end
    return str
end

--- 获取服务器当前时间戳
--- * 此方法在本地不能准确获取当前时间
---@return number
function htime.unix()
    return (hjapi.DzAPI_Map_GetGameStartTime() or 0) + htime.sec
end

--- 获取服务器当前时间对象
--- * 此方法在本地不能准确获取当前时间，将从UNIX元秒开始(1970年)
---@return table {Y:"年",m:"月",d:"日",H:"时",i:"分",s:"秒",w:"周[0-6]",W:"周[日-六]"}
function htime.date()
    return math.date(htime.unix())
end




--@see 下面都是过时的方法，由于计时器调用数量较多，故暂时保留
--@see 日后所有@deprecated将被删除，请及时替换为Timer方式
--@see 正则替换参考 htime.delTimer\((.*?)\) $1.destroy()

---@deprecated
htime.kernelInfo = function()
    print_err("kernelInfo@deprecated")
end

---@deprecated
---@return string HH:ii:ss
htime.his = function()
    return htime.gone()
end

---@deprecated
---@param t Timer
---@return number
htime.getSetTime = function(t)
    return t.period()
end

---@deprecated
---@param t Timer
---@return number
htime.getRemainTime = function(t)
    return t.remain()
end

---@deprecated
---@param t Timer
---@return number
htime.getElapsedTime = function(t)
    return t.elapsed()
end

---@deprecated
---@param t Timer
htime.pause = function(t)
    t.pause()
end

---@deprecated
---@param t Timer
htime.resume = function(t)
    t.resume()
end

---@deprecated
---@param t Timer
htime.delTimer = function(t)
    t.destroy()
end