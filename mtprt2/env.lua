S.llen = S.llen or {}   -- llen[stn_a][stn_b] = Leg length from waypoint a to b
S.t = S.t or {}         -- t[train_id] = {last = "last waypoint that the train passed", lasttime = "rwt that train passed last waypoint"}
S.lasts = S.lasts or {} -- For routing purposes.
S.dists = S.dists or {}

F.stn = {
    Etc = {name = "Estercroft", stops = {"EtcW", "EtcE"}},
    Wtv = {name = "Whitevale",  stops = {"WtvN", "WtvS"}}
}

function F.waypoint(name)
    if event.train then
        -- Update leg time
        if S.t[event.id] then
            local t_ = S.t[event.id]
            local new_time = rwt.to_secs(rwt.diff(t_.lasttime, rwt.now()))
            if new_time > 0 and ((not F.matread(S.llen, t_.last, name)) or new_time < F.matread(S.llen, t_.last, name)) then
                print("Time from", t_.last, "to", name, "updated from",
                    F.matread(S.llen, t_.last, name), "to", new_time)
                F.matwrite(S.llen, t_.last, name, new_time)
            end
        end
        S.t[event.id] = {last=name, lasttime=rwt.now()}
        
        -- Pop last waypoint
        if get_line() ~= "-" then
            if F.tkfirst(get_rc()) ~= name then print(name .. ": Current leg mismatch. Got " .. F.tkfirst(get_rc())) end
            set_rc(F.tkrest(get_rc()))
            local remainingTime = S.dists[name][F.tklast(get_rc())]
            -- Actual time, excluding all delays, is about remainingTime + 11. The 1.2 is here to anticipate for delays
            if remainingTime ~= nil then atc_set_text_inside(string.format("Arrival in %is", remainingTime * 1.2 + 11))
            else                         atc_set_text_inside("Arrival time unavailable")
            end
        end
    end
end

-- Guard ------------------------------------------------------
function F.stnguard(px,py,pz,sname)
  __approach_callback_mode = 1
  last_handled_train = last_handled_train or -1
  reserveCount = reserveCount or 0
  --local sname = sname or ""
  local p = POS(px,py,pz)
  
  --print(px, event.type, event.id, last_handled_train)
  
  if event.approach and event.id ~= last_handled_train then
      last_handled_train = event.id
      local will_dep = (reserveCount > 0) and can_set_route(p, "enter")
      local will_arr = (get_line() == sname)
      
      if will_dep or will_arr then atc_send("A0") end -- Station rails will re-enable ARS
      
      interrupt(0, {name = "approach", will_dep = will_dep, will_arr = will_arr})
      
  elseif F.int(event, "approach") then
      local M = event.msg
      
      if M.will_dep then
          digiline_send("lcd", "Car is arriving")
          reserveCount = reserveCount - 1
      end
      
      if M.will_dep or M.will_arr then
          set_route(p, "enter")
      else
          set_route(p, "skip")
      end
    
  elseif event.train then
    last_handled_train = -1 -- This is really to dedupe approach events
  elseif F.tctl(event, "reserveCount") then
      reserveCount = event.msg.count
  end
end

-- Platform -------------------------------------------------

function F.stnplat(pname, side)
  __approach_callback_mode = 1
  reserveDests = reserveDests or {}
  side = side or "L"
  
  if event.approach then
      if #reserveDests > 0 then
          atc_set_lzb_tsr(2)
          
          -- This might overheat the controller but who cares
          -- digiline_send("lcd", string.format("This car: %s", F.stn[reserveDests[1]].name or reserveDests[1]))
      end
  elseif event.train then
    if #reserveDests > 0 then
        --print("TrainArrived")
        atc_send(string.format("A0B0WO%s D10 A1OCD1SM", side))
        local dest = table.remove(reserveDests, 1)
        set_rc(F.route(pname, dest)) -- F.route(pname, dest) -- "Unk " .. dest
        set_line(dest)
        atc_set_text_outside("Train to " .. (F.stn[dest].name or dest))
        atc_set_text_inside("Welcome to the PRT.")
        digiline_send("tctl", {msg="reserveCount", count = #reserveDests})
        digiline_send("lcd", string.format("This car: %s", F.stn[dest].name or dest))
        F.scheduletimeout()
        
    else
        --print("TrainDropoff")
        set_rc("-")
        set_line("-")
        atc_set_text_inside("")
        atc_set_text_outside("")
        
        atc_send("A1")
    end
  end
  
  F.stn_reserve(pname)
  F.lcd_timeout()
end

function F.stn_reserve(pname)
    stationCursor = stationCursor or nil
    
    if F.tctl(event, "stationList") then
        local v
        stationCursor,v = next(F.stn, stationCursor)
        if stationCursor == nil then
          stationCursor,v = next(F.stn, stationCursor)
        end
        
        digiline_send("lcd", v.name)
        F.scheduletimeout()
    elseif F.tctl(event, "reserve") then
        local dest = stationCursor or "Etc" -- Is a station code
        
        -- Check for cars already going to this destination
        local i,v
        for i,v in ipairs(reserveDests) do
          if v == dest then
            digiline_send("lcd",
                string.format("Found | %s | Nr %s in queue", F.stn[dest].name or dest, i))
            F.scheduletimeout()
            return
          end
        end
        
        if F.route(pname, dest) == "" then
            digiline_send("lcd", string.format("No routes are currently available to %s.", F.stn[dest].name or dest))
            F.scheduletimeout()
            return
        end
        
        table.insert(reserveDests, dest)
        digiline_send("lcd", string.format("Reserved! | %s | %s in queue", F.stn[dest].name or dest, #reserveDests))
        digiline_send("tctl", {msg="reserveCount", count = #reserveDests})
        F.scheduletimeout()
    end
end

--= LCD timeout =------------

function F.scheduletimeout()
  clear_on = rwt.add(rwt.now(), 10)
  schedule_in(10, "display_timeout")
end

function F.lcd_timeout()
   if event.schedule and event.msg == "display_timeout" then
      clear_on = clear_on or rwt.now()
      reserveDests = reserveDests or {}
      
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
        digiline_send("lcd", string.format("%s in queue. | Next: %s", #reserveDests, F.stn[reserveDests[1]].name or reserveDests[1]))
      end
   end
end

-- DIJK ---------------------

function F.makeRoute()
    local function dijk(from)
        local queue = {from}
        local myDists = {}; myDists[from] = 0
        local myLasts = {}
        local function isLess(a, b)
            return (b == nil) or (a < b)
        end
        
        while #queue > 0 do
            i, cur = next(queue)
            for to, dist in pairs(S.llen[cur]) do
                if isLess(myDists[cur]+dist, myDists[to]) then
                    myLasts[to] = cur
                    myDists[to] = myDists[cur]+dist
                    table.insert(queue,to)
                end
            end
            table.remove(queue, i)
        end
        
        return myLasts, myDists
    end

    for stn,gr in pairs(S.llen) do
        S.lasts[stn], S.dists[stn] = dijk(stn)
    end
end

function F.route(from, to)
    local function r(from, to)
        local a = S.lasts[from][to]
        if from == to then return to
        else return r(from, a) .. " " ..  to
        end
    end
    
    local min = math.huge
    local best = ""
    --print(from, to)
    --print(F.stn[to].stops)
    for _,v in ipairs(F.stn[to].stops) do
        if S.dists[from][v] and S.dists[from][v] > 0 and S.dists[from][v] < min then
            min = S.dists[from][v]
            best = r(from, v)
        end
    end
    
    return best
end

-- Junctions ----------------

function F.junc(px, py, pz, paths)
     __approach_callback_mode = 1
    last_handled_train = last_handled_train or -1
    enabled = enabled or 1
    local p = POS(px,py,pz)
    local paths = paths or {}
    
    if event.approach and event.id ~= last_handled_train then
        lastVisit = lastVisit or {}
        
        last_handled_train = event.id
        -- Make sure the lastVisit entries exist + find the minimum
        local min = math.huge
        local min_v = nil
        for _,v in ipairs(paths) do
            lastVisit[v] = lastVisit[v] or -1
            if rwt.to_secs(lastVisit[v]) < min then
                min = rwt.to_secs(lastVisit[v])
                min_v = v
            end
        end
        
        if get_line() ~= "-" then
            -- Navigate to next waypoint
            -- Current station hasn't been popped yet. cadr time!
            interrupt(0, {name = "setRoute", route = F.tkfirst(F.tkrest(get_rc()))})
        else
            -- Go in the least recently visited direction
            interrupt(0, {name = "setRouteFlow", route = min_v})
        end
    elseif F.int(event, "setRouteFlow") then
        local route = event.msg.route
        
        if enabled == 0 then
            interrupt(10, {name = "setRouteFlow", route = route})
            return
        end
        
        if last_handled_train == -1 then
            --print(string.format("%s,%s,%s: Preferred route cleared already", px,py,pz))
            return
        end
        
        if lastVisit[route] == nil then
            print(string.format("%s,%s,%s: Requested nonexistent least visited %s", px,py,pz, route))
            return
        end
        while not can_set_route(p, route) do -- If route cannot be set, look for one that can
            route,_ = next(lastVisit, route)
            if route == nil then -- next's behaviour is annoying
              route,_ = next(lastVisit, route)
            end
            if route == event.msg.route then -- Made a complete loop -> try again
                --print(string.format("%s,%s,%s: Route %s blocked + no alts free", px,py,pz,route))
                set_route(p, route)
                interrupt(5, {name = "setRouteFlow", route = event.msg.route})
                return
            end
        end
        
        set_route(p, route)
        lastVisit[route] = rwt.now()
        -- DEBUG
        -- if route ~= event.msg.route then print(string.format("%s,%s,%s: Rerouted from %s to %s", px,py,pz,event.msg.route,route)) end
    elseif F.int(event, "setRoute") then
        local route = event.msg.route
        
        if enabled == 0 then
            interrupt(10, {name = "setRoute", route = route})
            return
        end
        
        if lastVisit[route] == nil then
            print(string.format("%s,%s,%s: Requested nonexistent next waypoint %s", px,py,pz, route))
            return
        end
        
        set_route(p, route)
        lastVisit[route] = rwt.now()
    elseif event.train then
        last_handled_train = -1 -- This is really to dedupe approach events
    elseif F.tctl(event, "j_breaker") then
        enabled = event.msg.enabled
        print(string.format("%s,%s,%s %s remotely!", px,py,pz, enabled==1 and "enabled" or "disabled"))
    end
end

--F.junc_ = F.junc -- Backwards compatiblity

-- Interval controller ------

function F.intervalctl(px,py,pz,rname)
    local INTERVAL = 40
    rname = rname or "Onward"
    if event.train then interrupt(INTERVAL, {name = "set"}) end
    if F.int(event, "set") then set_route(POS(px,py,pz), rname) end
    -- Also: add RC next_waypoint to the signal's onward route
end

-- Utilities ----------------

function F.int(event, name)
  return event.int and event.msg.name==name
end

function F.tctl(event, name)
    return event.digiline and event.channel == "tctl" and event.msg.msg == name
end

function F.matread(table,a,b)
    table = table or {}
    table[a] = table[a] or {}
    return table[a][b]
end

function F.matwrite(table,a,b,value)
    table = table or {}
    table[a] = table[a] or {}
    table[a][b] = value
end

function F.printWeb()
    for a,x in pairs(S.llen) do
        for b,t in pairs(x) do
            print(a, "->", b, "[len="..t.."];")
        end
    end
end

function F.tkfirst(tokens) return tokens:match("%S+") end

function F.tkrest(tokens) return tokens:match("%S+ (.*)") end

function F.tklast(tokens) return (" " .. tokens):match(".* (%S+)") end
