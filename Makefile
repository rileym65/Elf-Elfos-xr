PROJECT = xr

$(PROJECT).prg: $(PROJECT).asm bios.inc
	rcasm -l -v -x -d 1802 $(PROJECT) 2>&1 | tee $(PROJECT).lst
	cat $(PROJECT).prg | sed -f adjust.sed > x.prg
	rm $(PROJECT).prg
	mv x.prg $(PROJECT).prg

bios: $(PROJECT).asm bios.inc
	rcasm -l -v -x -d 1802 -DXRB $(PROJECT) 2>&1 | tee $(PROJECT).lst
	cat $(PROJECT).prg | sed -f adjust.sed > x.prg
	rm $(PROJECT).prg
	mv x.prg $(PROJECT).prg

uart: $(PROJECT).asm bios.inc
	rcasm -l -v -x -d 1802 -DXRU $(PROJECT) 2>&1 | tee $(PROJECT).lst
	cat $(PROJECT).prg | sed -f adjust.sed > x.prg
	rm $(PROJECT).prg
	mv x.prg $(PROJECT).prg

hex: $(PROJECT).prg
	cat $(PROJECT).prg | ../../tointel.pl > $(PROJECT).hex

bin: $(PROJECT).prg
	../../tobinary $(PROJECT).prg

install: $(PROJECT).prg
	cp $(PROJECT).prg ../../..
	cd ../../.. ; ./run -R $(PROJECT).prg

clean:
	-rm $(PROJECT).prg

