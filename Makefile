PYTHON = python3
GUI = marauders_gui.py
BIN = /usr/local/bin/marauders

run:
	@QT_QPA_PLATFORM=xcb $(PYTHON) $(GUI)

install:
	@printf '#!/bin/bash\n' > marauders_cmd
	@printf 'SCRIPT_DIR="$$(cd "$$(dirname "$$(readlink -f "$$0")")" && pwd)"\n' >> marauders_cmd
	@printf 'cd "$$SCRIPT_DIR" && QT_QPA_PLATFORM=xcb $(PYTHON) $(GUI)\n' >> marauders_cmd
	@chmod +x marauders_cmd
	@sudo ln -sf "$(PWD)/marauders_cmd" "$(BIN)"
	@echo "✅ Agora você pode abrir o programa digitando apenas: marauders"

uninstall:
	@sudo rm -f $(BIN)
