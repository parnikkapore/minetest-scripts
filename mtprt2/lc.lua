-- Don't forget to change the pin names!

if event.type=="on" and event.pin.name=="B" then
  digiline_send("tctl", { msg="stationList"})
end

if event.type=="on" and event.pin.name=="D" then
  digiline_send("tctl", { msg="reserve"})
end

-- LCD repeater (required in some designs)

if event.type=="digiline" and event.channel=="lcd" then
  digiline_send("lcd", event.msg)
end
