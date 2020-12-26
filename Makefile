PROJECT = xr

$(PROJECT).prg: $(PROJECT).asm bios.inc
	../dateextended.pl > date.inc
	../build.pl > build.inc
	cpp $(PROJECT).asm -o - | sed -e 's/^#.*//' > temp.asm
	rcasm -l -v -x -d 1802 temp 2>&1 | tee $(PROJECT).lst
	cat temp.prg | sed -f adjust.sed > $(PROJECT).prg

clean:
	-rm $(PROJECT).prg

