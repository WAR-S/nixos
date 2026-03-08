# Nix flake: общие флаги (flakes + nix-command)
NIX = nix --extra-experimental-features "nix-command flakes"

.PHONY: help iso iso-copy check clean clean-hard

help:
	@echo "nixos-nettop — цели:"
	@echo "  make iso        — собрать ISO, симлинк result -> каталог с образом"
	@echo "  make iso-copy   — собрать ISO и скопировать файл в текущую директорию (без result)"
	@echo "  make check      — nix flake check"
	@echo "  make clean      — удалить result и запустить nix store gc"
	@echo "  make clean-hard — nix-collect-garbage -d (агрессивная очистка)"

iso:
	$(NIX) build .#iso

iso-copy:
	$(NIX) run .#iso-build

check:
	$(NIX) flake check

clean:
	rm -f result result-*
	$(NIX) store gc

clean-hard:
	rm -f result result-*
	nix-collect-garbage -d
