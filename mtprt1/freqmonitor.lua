if event.train then
  if last_rt then
    local cdt = rwt.diff(last_rt, rwt.now())
    if dt then dt = rwt.to_secs(rwt.add(dt, cdt)) / 2
    else dt = rwt.to_secs(cdt)
    end

    digiline_send("prt_Telemetry",
      "Interval: " .. rwt.to_string(dt, true)
      .. " | Instant: " .. rwt.to_string(cdt, true) )
  else
    digiline_send("prt_Telemetry", "PRTC telemetry | Starting up...")
  end

  last_rt = rwt.now()
end

if event.digiline and event.channel == "prt_Telemetry_clear" then
  last_rt = nil
  dt = nil
  digiline_send("prt_Telemetry", "System reset!")
end
