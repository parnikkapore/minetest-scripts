S.Calls = S.Calls or {}
S.Callstr = S.Callstr or ""
F.stnName = {
  Org ="Origin",
  SkH ="Stacking Hill",
  FdV ="Framedrop Valley",
}

function F.stn(id, platform)
  -- persistent locals
  reserveDests = reserveDests or {} -- Top of list is reserved first

  -- code
  if event.train then
    if get_line() == id or get_line() == "Circling" then -- Train bound for here
      set_line("Circling")
      set_rc(S.Callstr)
    end

    if S.Calls[platform] then -- Pick up pax
      local dest = table.remove(reserveDests, 1)
      local destname = F.stnName[dest] or dest
      
      digiline_send("lcd", "This car: " .. destname)
      schedule_in(15, "display_timeout")
      atc_set_text_outside("Car to " .. destname)
      atc_set_text_inside("Welcome to the Blattertal PRT.")
      set_rc(platform) -- Just to make sure!
      set_line(dest)
      if #reserveDests == 0 then
        S.Calls[platform] = nil
        F.updateCallstr()
      end
    else
      -- Bug workaround - Otherwise the station will disable ARS, we'll decide to skip it, and then ARS never gets enabled again
      -- atc_set_disable_ars(false)
      atc_send("A1")
    end
  elseif event.digiline and event.channel == "tctl" then -- "Train control"
    F.digiterm(event.msg, platform)
  elseif event.schedule and event.msg=="display_timeout" then
    F.lcdtimeout()
  end
end

function F.digiterm(d, pid)
  if d.msg == "Reserve" then
  
    if not d.dest then
      digiline_send("lcd", "Malformed parameters: Did not give destination")
      return
    end
    
    -- Check for cars already going to this destination
    for i,v in ipairs(reserveDests) do
      if v == d.dest then
        digiline_send("lcd", "Found | "
          .. (F.stnName[d.dest] or d.dest)
          .. " | Nr " .. i .. " in queue")
        return
      end
    end
    
    table.insert(reserveDests, d.dest)
    S.Calls[pid] = 1
    F.updateCallstr()
    digiline_send("lcd", "Reserved! | " 
        .. (F.stnName[d.dest] or d.dest) 
        .. " | Nr " .. #reserveDests .. " in queue")
        
  elseif d.msg == "stationList" then
    k = d.k
    k,v = next(F.stnName, k)
    while k == nil do
      k,v = next(F.stnName, k)
    end
    digiline_send("nextStn", {code=k, name=v})
  elseif d.msg == "clearQueue" then
    reserveDests = {}
  elseif d.msg == "listQueue" then
    print(#reserveDests)
    print(reserveDests)
  end

  F.scheduletimeout()
end

--= LCD timeout =--

function F.scheduletimeout()
  clear_on = rwt.add(rwt.now(), 10)
  schedule_in(10, "display_timeout")
end

function F.lcdtimeout()
  clear_on = clear_on or rwt.now()
  
  if rwt.diff(rwt.now(), clear_on) > 0 then
    --print("!a Retrying to timeout display in ", rwt.diff(rwt.now(), clear_on))
    schedule_in(rwt.diff(rwt.now(), clear_on), "display_timeout")
    return
  else
    --print("!a Successfully timed out display")
  end
  
  if #reserveDests == 0 then
    digiline_send("lcd", "Press the left button to pick a destination.")
  else
    digiline_send("lcd", #reserveDests .. " in queue. | Next: "
      .. (F.stnName[reserveDests[1]] or reserveDests[1]))
  end
end

--= Libs =--

function F.updateCallstr()
  S.Callstr = ""
  for k in pairs(S.Calls) do
    S.Callstr = S.Callstr .. k .. " "
  end
end

function F.updateRoutes()
  if event.train then
    if get_line() == "Circling" 
       or get_line() == ""
       or not get_line()
    then
      set_line("Circling")
      atc_set_text_outside("Looking for passengers")
      atc_set_text_inside(S.Callstr)
      set_rc(S.Callstr)
    else
      set_rc(get_line())
    end
  end
end

--=== Announcements system ===--

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
