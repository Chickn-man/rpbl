#
#  Makefile for building RPBL
#
##############################################################################
#
#  Copyright (C) 2023 Keegan Powers
#
#  This file is part of RPBL
#
#  RPBL is free software: you can redistribute it
#  and/or modify it under the terms of the GNU General Public
#  License as published by the Free Software Foundation, either
#  version 3 of the License, or (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program. If not, see <https://www.gnu.org/licenses/>.
#
##############################################################################

PROGNAME = bootloader

CC = cc65
AS = acme
LD = ld65

INCS =
LIBS =

LDS = linker.ld
CFLAGS = $(LIBS) $(INCS)
ASFLAGS =
LDFLAGS =

SRCDIR := src
OBJDIR := lib
BUILDDIR := bin

.PHONY: build
build: setup
	@ $(AS) $(ASFLAGS) -o $(OBJDIR)/boot.o -f plain $(SRCDIR)/boot.s
	-@ rm $(BUILDDIR)/boot.bin
	@ dd if=$(OBJDIR)/boot.o of=$(BUILDDIR)/boot.bin bs=128 skip=10 count=4
	@ dd if=$(OBJDIR)/boot.o of=$(BUILDDIR)/exboot.bin bs=128 skip=14 count=4

.PHONY: setup
setup:
	@ mkdir -p $(SRCDIR)
	@ mkdir -p $(OBJDIR)
	@ mkdir -p $(BUILDDIR)

.PHONY: clean
clean:
	-@ rm -r $(BUILDDIR)
	-@ rm -r $(OBJDIR)