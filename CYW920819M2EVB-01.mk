#
# Copyright 2016-2023, Cypress Semiconductor Corporation (an Infineon company) or
# an affiliate of Cypress Semiconductor Corporation.  All rights reserved.
#
# This software, including source code, documentation and related
# materials ("Software") is owned by Cypress Semiconductor Corporation
# or one of its affiliates ("Cypress") and is protected by and subject to
# worldwide patent protection (United States and foreign),
# United States copyright laws and international treaty provisions.
# Therefore, you may use this Software only as provided in the license
# agreement accompanying the software package from which you
# obtained this Software ("EULA").
# If no EULA applies, Cypress hereby grants you a personal, non-exclusive,
# non-transferable license to copy, modify, and compile the Software
# source code solely for use in connection with Cypress's
# integrated circuit products.  Any reproduction, modification, translation,
# compilation, or representation of this Software except as specified
# above is prohibited without the express written permission of Cypress.
#
# Disclaimer: THIS SOFTWARE IS PROVIDED AS-IS, WITH NO WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, NONINFRINGEMENT, IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. Cypress
# reserves the right to make changes to the Software without notice. Cypress
# does not assume any liability arising out of the application or use of the
# Software or any product or circuit described in the Software. Cypress does
# not authorize its products for use in any products where a malfunction or
# failure of the Cypress product may reasonably be expected to result in
# significant property damage, injury or death ("High Risk Product"). By
# including Cypress's product in a High Risk Product, the manufacturer
# of such system or application assumes all risk of such use and in doing
# so agrees to indemnify Cypress against all liability.
#

ifeq ($(WHICHFILE),true)
$(info Processing $(lastword $(MAKEFILE_LIST)))
endif

#
# Device definition
#
DEVICE=CYW20819A1KFBG
CHIP=20819
CHIP_FOR_PATH=20819
CHIP_REV=A1
BLD=A

# CSP baselib and BSP path variables
CY_TARGET_DEVICE?=$(CHIP_FOR_PATH)$(CHIP_REV)
CY_APP_PATCH_LIBS+=$(CY_$(CY_TARGET_DEVICE)_APP_PATCH_LIBS)
COMPONENTS+=$(CY_TARGET_DEVICE) $(COMPONENTS_$(CY_TARGET_DEVICE))
ifeq ($(SEARCH_$(CY_TARGET_DEVICE)),)
# internal only - app deploys will always initialize this in mtb.mk
SEARCH_$(CY_TARGET_DEVICE)?=$(IN_REPO_BTSDK_ROOT)/wiced_btsdk/dev-kit/baselib/$(CY_TARGET_DEVICE)
SEARCH+=$(SEARCH_$(CY_TARGET_DEVICE))
endif
CY_BSP_PATH?=$(SEARCH_TARGET_$(TARGET))
# ensure the baselib has been instantiated (in case make getlibs had already been performed, but for a BSP with a different CSP
ifneq ("$(wildcard $(SEARCH_$(CY_TARGET_DEVICE))/COMPONENT_$(CY_TARGET_DEVICE))","")
CY_BASELIB_PATH?=$(SEARCH_$(CY_TARGET_DEVICE))/COMPONENT_$(CY_TARGET_DEVICE)
CY_BASELIB_CORE_PATH?=$(SEARCH_core-make)
CY_INTERNAL_BASELIB_PATH?=$(patsubst %/,%,$(CY_BASELIB_PATH))
override CY_DEVICESUPPORT_SEARCH_PATH:=$(call CY_MACRO_SEARCH,devicesupport.xml,$(CY_INTERNAL_BASELIB_PATH))
endif

# declare which stack version to use in COMPONENT folders
COMPONENTS+=btstack_v1

#
# Define the features for this target
#
CY_CORE_OTA_FW_UPGRADE_STORE?=external_sflash

# board has external LPO
USE_32K_EXTERNAL_LPO?=1
CY_CORE_DEFINES+=-DUSE_32K_EXTERNAL_LPO=$(USE_32K_EXTERNAL_LPO)

# Do RF Calibration to ensure output tx power accuracy
CY_CORE_DEFINES+=-DDO_RF_CALIBRATION

# Begin address of flash0, on-chip flash
CY_FLASH0_BEGIN_ADDR=0x00500000
# Available flash = 128 * 2048 = 256k
CY_FLASH0_LENGTH=0x00040000
# Entry-point symbol for application
CY_CORE_APP_ENTRY:=spar_crt_setup

#
# TARGET UART parameters
#
# Max. supported baudrate by this platform
CY_CORE_DEFINES+=-DHCI_UART_MAX_BAUD=4000000
# default baud rate is 3M, that is the max supported on macOS
CY_CORE_DEFINES+=-DHCI_UART_DEFAULT_BAUD=3000000
ifneq ($(KITPROG3_USE_1_STOP_BIT),1)
# need to set 2 stop bits for KitProg3 at 3M baud rate
CY_CORE_DEFINES+=-DKITPROG3_USE_2_STOP_BITS
endif

#
# pins supporting SWD hardware debugging
#
CY_CORE_DEFINES+=-DCY_PLATFORM_SWDCK=WICED_P02
CY_CORE_DEFINES+=-DCY_PLATFORM_SWDIO=WICED_P03

#
# Patch variables
#
CY_CORE_PATCH=$(CY_INTERNAL_BASELIB_PATH)/internal/$(CY_TARGET_DEVICE)/patches/patch.elf
CY_CORE_PATCH_CFLAGS=$(CY_INTERNAL_BASELIB_PATH)/internal/$(CY_TARGET_DEVICE)/gcc/$(CY_TARGET_DEVICE).cflag
CY_CORE_PATCH_LIB_PATH=libraries/prebuilt

#
# Variables for pre-build and post-build processing
#
CY_CORE_HDF=$(CY_INTERNAL_BASELIB_PATH)/internal/$(CY_TARGET_DEVICE)/configdef$(CY_TARGET_DEVICE).hdf
CY_CORE_HCI_ID=$(CY_INTERNAL_BASELIB_PATH)/platforms/CYW208XXA1_IDFILE.txt
CY_CORE_BTP=$(CY_INTERNAL_BASELIB_PATH)/platforms/208XX_OCF.btp
CY_CORE_MINIDRIVER=$(CY_INTERNAL_BASELIB_PATH)/platforms/minidriver-$(CY_TARGET_DEVICE)-uart-patchram.hex
CY_CORE_CGSLIST=\
    $(CY_INTERNAL_BASELIB_PATH)/internal/$(CY_TARGET_DEVICE)/patches/patch.cgs\
    $(CY_INTERNAL_BASELIB_PATH)/platforms/CYW208XXA1.cgs

#
# read in BTP file as single source of flash layout information
#
define \n


endef

define extract_btp_file_value
$(patsubst $1=%,%,$(filter $1%,$2))
endef

# these make targets do not need this data and don't work if importing an app
# that has not yet run make getlibs, so skip it
ifeq ($(filter import_deps getlibs get_app_info,$(MAKECMDGOALS)),)

# override core-make buggy CY_SPACE till it's fixed
CY_EMPTY=
CY_SPACE=$(CY_EMPTY) $(CY_EMPTY)

# split up btp file into "x=y" text
CY_BT_FILE_TEXT:=$(shell cat -e $(CY_CORE_BTP))
CY_BT_FILE_TEXT:=$(subst $(CY_SPACE),,$(CY_BT_FILE_TEXT))
CY_BT_FILE_TEXT:=$(subst ^M,,$(CY_BT_FILE_TEXT))
CY_BT_FILE_TEXT:=$(patsubst %$(\n),% ,$(CY_BT_FILE_TEXT))
CY_BT_FILE_TEXT:=$(subst $$,$(CY_SPACE),$(CY_BT_FILE_TEXT))

ifeq ($(CY_BT_FILE_TEXT),)
$(error Failed to parse BTP variables from file: $(CY_CORE_BTP))
endif

SS_LOCATION = $(call extract_btp_file_value,DLConfigSSLocation,$(CY_BT_FILE_TEXT))
VS_LOCATION = $(call extract_btp_file_value,DLConfigVSLocation,$(CY_BT_FILE_TEXT))
VS_LENGTH = $(call extract_btp_file_value,DLConfigVSLength,$(CY_BT_FILE_TEXT))
DS_LOCATION = $(call extract_btp_file_value,ConfigDSLocation,$(CY_BT_FILE_TEXT))
DS2_LOCATION = $(call extract_btp_file_value,ConfigDS2Location,$(CY_BT_FILE_TEXT))

endif # end filter import_deps getlibs get_app_info

# OTA
ifeq ($(OTA_FW_UPGRADE),1)
DS2_APP_PATH=$(SEARCH_btsdk-ota)/COMPONENT_ds2_app
CY_DS2_APP_HEX=$(DS2_APP_PATH)/build/$(TARGET)/$(CONFIG)/ds2_app_$(CY_CORE_OTA_FW_UPGRADE_STORE).hex
CY_APP_OTA=OTA
CY_APP_OTA_DEFINES=-DOTA_FW_UPGRADE=1
ifeq ($(CY_APP_SECURE_OTA_FIRMWARE_UPGRADE),1)
CY_APP_OTA_DEFINES+=-DOTA_SECURE_FIRMWARE_UPGRADE
endif
ifeq ($(CY_CORE_OTA_FW_UPGRADE_STORE),on_chip_flash)
CY_APP_OTA_DEFINES+=-DOTA_FW_UPGRADE_EFLASH_COPY
endif
ifeq ($(CY_CORE_OTA_FW_UPGRADE_STORE),external_sflash)
CY_APP_OTA_DEFINES+=-DOTA_FW_UPGRADE_SFLASH_COPY -DENABLE_SFLASH_UPGRADE
CY_APP_OTA_DEFINES+=-DOTA_SFLASH_SECTOR_SIZE=4096
# default for off-chip encryption
OFU_UPGRADE_ENCRYPT_SFLASH_DATA ?= 1
ifeq ($(OFU_UPGRADE_ENCRYPT_SFLASH_DATA),1)
CY_DS2_APP_HEX=$(DS2_APP_PATH)/build/$(TARGET)/$(CONFIG)/ds2_app_$(CY_CORE_OTA_FW_UPGRADE_STORE)_encrypt.hex
CY_APP_OTA_DEFINES += -DOTA_ENCRYPT_SFLASH_DATA
endif
endif
-include $(SEARCH_btsdk-ota)/COMPONENT_ds2_app/GNUmakefile
else
DS2_LOCATION=$(shell env printf "0x%06X" $$(($(CY_FLASH0_BEGIN_ADDR)+$(CY_FLASH0_LENGTH))))
endif

# use flash offset and length to limit xip range
ifneq ($(CY_FLASH0_BEGIN_ADDR),)
CY_CORE_LD_DEFS+=FLASH0_BEGIN_ADDR=$(CY_FLASH0_BEGIN_ADDR)
endif
ifneq ($(CY_FLASH0_LENGTH),)
CY_CORE_LD_DEFS+=FLASH0_LENGTH=$(CY_FLASH0_LENGTH)
endif

# XIP
CY_CORE_XIP_SRC=$(CY_RECIPE_SOURCE)
CY_CORE_XIP_OBJ=$(subst $(CY_SPACE),;,$(filter %.$(CY_TOOLCHAIN_SUFFIX_O),$(CY_CORE_XIP_SRC:%.$(CY_TOOLCHAIN_SUFFIX_C)=%.$(CY_TOOLCHAIN_SUFFIX_O))))
CY_CORE_APP_SPECIFIC_DS_LEN?=0x80

ifeq ($(XIP),xip)
CY_CORE_APP_XIP_EXTRA=_XIP_
CY_CORE_LD_DEFS+=XIP_DS_OFFSET=$(CY_CORE_APP_SPECIFIC_DS_LEN)
CY_CORE_LD_DEFS+=XIP_OBJ=$(CY_CORE_XIP_OBJ)
CY_CORE_LD_DEFS+=XIP_LEN=0x$(shell env printf "%08x" $$(($(DS2_LOCATION) - $(DS_LOCATION) - $(CY_CORE_APP_SPECIFIC_DS_LEN))))
# add config "skip" record for xip block
CY_CORE_CGSLIST+=$(CY_INTERNAL_BASELIB_PATH)/platforms/add_xip_skip_config.cgs
endif

ifeq ($(OTA_FW_UPGRADE),1)
ifneq ($(CY_CORE_OTA_FW_UPGRADE_STORE),)
# DS2 app is prebuilt and supplied as a hex file
# prebuilt from apps/ota/ds2_app
# the DS2 config records do not install patches - this code is running on bare ROM
# for fw update case, sflash image is copied to DS1, then DS1 signature is set active
# DS2 app will take a small part of on-chip flash
CY_CORE_DS2_LEN = 0x1000
CY_CORE_LD_DEFS += APP_DS2_LEN=$(CY_CORE_DS2_LEN)
CY_CORE_LD_DEFS += DS_LOCATION=$(DS_LOCATION)
CY_CORE_DS2_EXTRA = _APPDS2_
# calculate DS2 offset to override value from BTP file
DS2_LOCATION=$(shell env printf "0x%06X" $$(($(SS_LOCATION)+$(CY_FLASH0_LENGTH)-$(CY_CORE_DS2_LEN))))
CY_CORE_CGS_ARGS+=-O ConfigDS2Location:$(DS2_LOCATION)
endif
endif

ifneq ($(APP_STATIC_DATA),)
# HomeKit requires 0x1000 bytes of static section to store manufacturer data
# calculate new VS/DS location to override values from BTP file
VS_LOCATION=$(shell env printf "0x%06X" $$(($(SS_LOCATION)+(0x1000))))
ifneq ($(VS_LENGTH_OVERRIDE),)
VS_LENGTH=$(VS_LENGTH_OVERRIDE)
CY_CORE_CGS_ARGS+=-O DLConfigVSLength:$(VS_LENGTH)
endif
DS_LOCATION=$(shell env printf "0x%06X" $$(($(VS_LOCATION)+$(VS_LENGTH))))
CY_CORE_CGS_ARGS+=-O DLConfigVSLocation:$(VS_LOCATION) -O ConfigDSLocation:$(DS_LOCATION)
endif

# defines necessary for flash layout
CY_CORE_DEFINES+=-DSS_LOCATION=$(SS_LOCATION) -DVS_LOCATION=$(VS_LOCATION) -DDS_LOCATION=$(DS_LOCATION) -DDS2_LOCATION=$(DS2_LOCATION)

CY_CORE_LD_DEFS+=\
	SRAM_BEGIN_ADDR=0x00200000 \
	SRAM_LENGTH=0x00028000 \
	PRAM_BEGIN_ADDR=0x00270400 \
	PRAM_LENGTH=0x00003C00 \
	AON_AREA_END=0x00204574 \
	ISTATIC_BEGIN=0x500C00 \
	ISTATIC_LEN=0x400 \
	OTA_UPGRADE_STORE=$(CY_CORE_OTA_FW_UPGRADE_STORE) \
	NUM_PATCH_ENTRIES=256
