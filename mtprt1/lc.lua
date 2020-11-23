-- Don't forget to check the pin names!

mem.code = mem.code or nil

if event.type=="on" and event.pin.name=="B" then
  digiline_send("tctl", { msg="stationList", k=mem.code})
end

if event.type=="on" and event.pin.name=="D" then
  digiline_send("tctl", { msg="Reserve", dest=mem.code})
end

if event.type=="digiline" and event.channel=="lcd" then
  digiline_send("lcd", event.msg)
end

if event.type=="digiline" and event.channel=="nextStn" then
  mem.code = event.msg.code
  digiline_send("lcd", event.msg.name)
end
