#! /bin/sh

#dijkstra -dp SkHE network_future.gv | gvpr -c -f b.gvpr | dot -K neato -O -T jpg

dijkstra -dp J03 network_future.gv | gvpr -c -f c.gvpr | dot -K neato -O -T jpg
