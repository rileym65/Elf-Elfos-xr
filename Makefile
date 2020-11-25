PROJECT = xr

$(PROJECT).prg: $(PROJECT).asm bios.inc
	../date.pl > date.inc
	cpp $(PROJECT).asm -o - | sed -e 's/^#.*//' > temp.asm
	rcasm -l -v -x -d 1802 temp
	cat temp.prg | sed -f adjust.sed > $(PROJECT).prg

clean:
	-rm $(PROJECT).prg

