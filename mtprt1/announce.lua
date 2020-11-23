-- PRT announcements experimental code - ATC panel

-- Should be in init code
S.announce = S.announce or {"No announcements."}

-- F.announceBox()

-- persistent locals
  lastShownID = lastShownID or nil

  if  event.digiline
  and event.channel=="prt_announcements" 
  and event.msg == "GET"
  then
    local v
    while not v do
      lastShownID, v = next(S.announce, lastShownID)
    end
    digiline_send("prt_announcements", v)
  end

-- PRT announcements experimental code - Luacontroller

BLINKY_PORT = "B"

if (event.type == "on" and event.pin.name == BLINKY_PORT) then
  digiline_send("prt_announcements", "GET")
end

if (event.type == "digiline" and event.channel == "prt_announcements") then
  digiline_send("lcd_annos", event.msg)
end
