--= ATC panel (init code) =----------------------------------------------------

S.announce = S.announce or {"No announcements."}

function F.announceBox()
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
end

--= Luacontroller =------------------------------------------------------------

BLINKY_PORT = "B"

if (event.type == "on" and event.pin.name == BLINKY_PORT) then
  digiline_send("prt_announcements", "GET")
end

if (event.type == "digiline" and event.channel == "prt_announcements") then
  digiline_send("lcd_annos", event.msg)
end

--= Announcements setting station =--------------------------------------------

S.announce = {
    "Welcome to the PRT.",
    "Latest station: Clarkwich",
    "A minibook about the system is being written"
}
print("Announcement changed!")

--= Preview box =--------------------------------------------------------------

lastShownID = lastShownID or nil

if event.punch then
  local v
  while not v do
  lastShownID, v = next(S.announce, lastShownID)
  end
  digiline_send("lcd_annos", v)
end
