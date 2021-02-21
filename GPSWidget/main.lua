local dir = "/WIDGETS/GPSWidget/"
local data = {
    telem = false,
    satelliteId = -1,
    gpsId = -1,
    altId = -1,
    gpsFix = false,
    gpsFixPrev = false,
    gps = {},
    satellite = 0,
    alt = 0,
    hdop = 0
}
local image = {
    bg,
    gpsRed,
    gpsGreen,
    logRed,
    logGreen
}
local options = {
    {"GpsLog", BOOL, 1},
    {"GpsVoice", BOOL, 1} 
}
local logTimer = getTime()
local logOk = false

local function gpsLog()

    local today = getDateTime()
    local f = io.open(dir .. "log/" .. today.year .. 
                     ((today.mon < 10) and "0" or "") .. today.mon ..
                     ((today.day < 10) and "0" or "") .. today.day .. ".csv", "a")

    if(f) then
         local fw = io.write(f, data.gps.lat, ",", data.gps.lon, ",", 
                            ((today.hour < 10) and "0" or "") , today.hour, ":", 
                            ((today.min < 10) and "0" or "") , today.min, ":", 
                            ((today.sec < 10) and "0" or "") , today.sec, "\r\n")
         if(not fw) then
            io.close(f)
            return false
         end
    else
        return false
    end

    io.close(f)
    return true
end

local function createWgt(zone, options)
    
    data.satelliteId = getFieldInfo("Tmp2") and getFieldInfo("Tmp2").id or -1
    data.gpsId = getFieldInfo("GPS") and getFieldInfo("GPS").id or -1
    data.altId = getFieldInfo("GAlt") and getFieldInfo("GAlt").id or -1

    if(data.satelliteId ~= -1 and data.gpsId ~= -1 and data.altId ~= -1) then data.telem = true end

    image.bg = Bitmap.open(dir .. "img/bg.png")
    image.gpsGreen = Bitmap.open(dir .. "img/gps_green.png")
    image.gpsRed = Bitmap.open(dir .. "img/gps_red.png")
    image.logGreen = Bitmap.open(dir .. "img/log_green.png")
    image.logRed = Bitmap.open(dir .. "img/log_red.png")

    local wgt = {zone=zone, options=options}
    return wgt
end

local function updateWgt(wgt, options)
    wgt.options = options
end

local function backgroundWgt(wgt)

    if(not data.telem) then return end

    local gpsTemp = getValue(data.gpsId)
    data.satellite = getValue(data.satelliteId)
    data.alt = getValue(data.altId)

    if(type(gpsTemp) == "table" and gpsTemp.lat ~= nil and gpsTemp.lon ~= nil) then
        data.gps = gpsTemp
        if(data.satellite > 1000 and gpsTemp.lat ~= 0 and gpsTemp.lon ~= 0) then
            data.gpsFix = true
        end
    else
        data.gpsFix = false
    end   

    data.hdop = (9 - (math.floor(data.satellite * 0.01) % 10)) * 0.5 + 1.0

    if(data.gpsFix and wgt.options.GpsLog == 1 and (getTime() - logTimer) > 100) then
        logOk = gpsLog()
        logTimer = getTime()
    end
end

local function refreshWgt(wgt)

    if(wgt.zone.w < 180) then 
        lcd.drawText(wgt.zone.x, wgt.zone.y, "Need more space.")
        return
    end

    lcd.drawBitmap(image.bg, wgt.zone.x, wgt.zone.y)
    if(not data.telem) then 
        lcd.drawText(wgt.zone.x, wgt.zone.y, "No telemetry data.")
        return 
    end
    
    backgroundWgt(wgt)

    if(data.gpsFix and not data.gpsFixPrev) then
        data.gpsFixPrev = true
        if(wgt.options.GpsVoice == 1) then 
            playFile(dir .. "sound/gps.wav")
            playFile(dir .. "sound/good.wav")
        end
    elseif(not data.gpsFix and data.gpsFixPrev) then
        data.gpsFixPrev = false
        if(wgt.options.GpsVoice == 1) then 
            playFile(dir .. "sound/gps.wav")
            playFile(dir .. "sound/bad.wav")
        end
    end
    
    lcd.drawBitmap(data.gpsFix and image.gpsGreen or image.gpsRed, wgt.zone.x + (wgt.zone.w - 25), wgt.zone.y + 5)
    lcd.drawText(wgt.zone.x + 1, wgt.zone.y, "Sat:" .. (data.satellite % 100) .. " Hdop:" .. 
                (data.hdop == 5.5 and ">" or "") .. (data.hdop == 1.0 and "<=" or "") .. data.hdop, SHADOWED)
    lcd.drawText(wgt.zone.x + 1, wgt.zone.y + 16, "GPS Alt:" .. string.format("%.1f", data.alt) .. "m ", SHADOWED)
    lcd.drawText(wgt.zone.x + 1, wgt.zone.y + 36, "Lat:" .. (data.gps.lat and string.format("%.6f", data.gps.lat) or "No data.") .. " ", SMLSIZE)
    lcd.drawText(wgt.zone.x + 1, wgt.zone.y + 48, "Lon:" .. (data.gps.lon and string.format("%.6f", data.gps.lon) or "No data.") .. " ", SMLSIZE)
    
    if(wgt.options.GpsLog == 1) then
        if(data.gpsFix) then
            lcd.drawBitmap(logOk and image.logGreen or image.logRed, wgt.zone.x + (wgt.zone.w - 68), wgt.zone.y + 40)
        else
            lcd.drawBitmap(image.logRed, wgt.zone.x + (wgt.zone.w - 68), wgt.zone.y + 40)
        end
    end

end

return {name="GPSWidget", options=options, create=createWgt, update=updateWgt, refresh=refreshWgt, background=backgroundWgt}