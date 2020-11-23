S.sN = S.sN or {} --S.sN.Stn = "station name"
S.lS = S.lS or {} -- Last stop by train id
S.nS = S.nS or {} -- Next signal by signal ID

function F.stn(sig, side, switch, spd)
    side = side or "L"
    side = (switch) and (side .. "R") or side
    spd  = spd or "M"

    if event.train then
        atc_send("B0W O" .. side)
        atc_set_text_inside(S.sN[string.sub(sig, 1, 3)] or "At station")
        interrupt(10, "Dep")
    end
    if event.int and event.message=="Dep" then
        if getstate(sig) == "red" then
            atc_set_text_inside(S.sN[string.sub(sig, 1, 3)] .. "n Departure delayed; Waiting for next station to be cleared")
            interrupt(1, "Dep")
        else
            setstate(sig, "red")
            if switch then
                setstate(switch, "cr")
                interrupt(10, "Rst")
            end
            atc_send("OCD1S" .. spd)
            atc_set_text_inside("Next stop: " .. (S.sN[S.nS[sig]] or "New station"))
            if S.lS[atc_id] then 
                setstate(S.lS[atc_id], "green")
                S.nS[S.lS[atc_id]] = string.sub(sig, 1, 3)
            end
            S.lS[atc_id] = sig
        end
    end
    if event.int and event.message=="Rst" then setstate(switch, "st") end
end

function F.slow()
  if event.train then
    atc_send("B2S2")
    atc_set_text_inside("Approaching " .. (S.sN[S.nS[S.lS[atc_id]]] or "new station"))
  end
end

function F.setLine(line)
  if event.train then
    atc_set_text_outside(line)
  end
end
