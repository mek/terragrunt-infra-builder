default:
	@echo " clean"

clean:
	@find . -type f -name '*~' | xargs rm
