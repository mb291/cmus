#!/bin/sh
#
# Copyright 2005 Timo Hirvonen
#
# This file is licensed under the GPLv2.

. scripts/configure-private.sh || exit 1

# Add --enable-FEATURE and --disable-FEATURE flags
#
# @name:          name of the flag (eg. alsa => --enable-alsa)
# @default_value: 'y', 'n' or 'a' (yes, no, auto)
#                 'a' can be used only if check_@name function exists
# @config_var:    name of the variable
# @description:   text shown in --help
#
# defines @config_var=y/n
#
# NOTE:
#   You might want to define check_@name function which will be run by
#   run_checks.  The check_@name function takes no arguments and _must_ return
#   0 on success and non-zero on failure. See checks.sh for more information.
#
# Example:
#   ---
#   check_alsa()
#   {
#     pkg_check_modules alsa "alsa"
#     return $?
#   }
#
#   enable_flag alsa a CONFIG_ALSA "ALSA support"
#   ---
enable_flag()
{
	argc enable_flag $# 4 4
	before parse_command_line enable_flag

	case $2 in
		y|n)
			set_var $3 $2
			;;
		a)
			# 'auto' looks prettier than 'a' in --help
			set_var $3 auto
			;;
		*)
			die "default value for an enable flag must be 'y', 'n' or 'a'"
			;;
	esac

	enable_flags="${enable_flags} $1"
	set_var enable_var_${1} $3
	set_var enable_desc_${1} "$4"
}

# Add an option flag
#
# @flag:          'foo' -> --foo[=ARG]
# @has_arg:       does --@flag take an argument? 'y' or 'n'
# @function:      function to run if --@flag is given
# @description:   text displayed in --help
# @arg_desc:      argument description shown in --help (if @has_arg is 'y')
add_flag()
{
	argc add_flag $# 4 5
	before parse_command_line add_flag

	case $2 in
		y|n)
			;;
		*)
			die "argument 2 for add_flag must be 'y' or 'n'"
			;;
	esac
	__name="$(echo $1 | sed 's/-/_/g')"
	opt_flags="$opt_flags $__name"
	set_var flag_hasarg_${__name} "$2"
	set_var flag_func_${__name} "$3"
	set_var flag_desc_${__name} "$4"
	set_var flag_argdesc_${__name} "$5"
}

# Set and register variable to be added to config.mk
#
# @name   name of the variable
# @value  value of the variable
makefile_var()
{
	argc makefile_var $# 2 2
	after parse_command_line makefile_var
	before generate_config_mk makefile_var

	set_var $1 "$2"
	makefile_vars $1
}

# Register variables to be added to config.mk
makefile_vars()
{
	before generate_config_mk makefile_vars

	makefile_variables="$makefile_variables $*"
}

# -----------------------------------------------------------------------------
# Config header generation

# Simple interface
#
# Guesses variable types:
#   y or n        -> bool
#   [0-9]+        -> int
#   anything else -> str
#
# Example:
#   CONFIG_FOO=y  # bool
#   VERSION=2.0.1 # string
#   DEBUG=1       # int
#   config_header config.h CONFIG_FOO VERSION DEBUG
config_header()
{
	argc config_header $# 2
	after run_checks config_header

	config_header_begin "$1"
	shift
	while test $# -gt 0
	do
		__var=$(get_var $1)
		case "$__var" in
		[yn])
			config_bool $1
			;;
		*)
			if test "$__var" && test "$__var" = "$(echo $__var | sed 's/[^0-9]//g')"
			then
				config_int $1
			else
				config_str $1
			fi
			;;
		esac
		shift
	done
	config_header_end
}

# Low-level interface
#
# Example:
#   config_header_begin config.h
#   config_str PACKAGE VERSION
#   config_bool CONFIG_ALSA
#   config_header_end

config_header_begin()
{
	argc config_header_begin $# 1 1
	after run_checks config_header_begin

	config_header_file="$1"
	config_header_tmp=$(tmp_file config_header)

	__def=$(echo $config_header_file | to_upper | sed 's/[-\.\/]/_/g')
	cat <<EOF > "$config_header_tmp"
#ifndef $__def
#define $__def

EOF
}

config_str()
{
	while test $# -gt 0
	do
		echo "#define $1 \"$(get_var $1)\"" >> "$config_header_tmp"
		shift
	done
}

config_int()
{
	while test $# -gt 0
	do
		echo "#define $1 $(get_var $1)" >> "$config_header_tmp"
		shift
	done
}

config_bool()
{
	while test $# -gt 0
	do
		case "$(get_var $1)" in
			n)
				echo "/* #define $1 */" >> "$config_header_tmp"
				;;
			y)
				echo "#define $1 1" >> "$config_header_tmp"
				;;
			*)
				die "bool '$1' has invalid value '$(get_var $1)'"
				;;
		esac
		shift
	done
}

config_header_end()
{
	argc config_header_end $# 0 0
	echo "" >> "$config_header_tmp"
	echo "#endif" >> "$config_header_tmp"
	mkdir -p $(dirname "$config_header_file")
	update_file "$config_header_tmp" "$config_header_file"
}

# -----------------------------------------------------------------------------

# Print values for enable flags
print_config()
{
	echo
	echo "Configuration:"
	for __flag in $enable_flags
	do
		__var=$(get_var enable_var_${__flag})
		strpad "${__flag}: " 21
		echo "${strpad_ret}$(get_var $__var)"
	done
}

# deprecated. pass the check_* functions directly to run_checks
add_check()
{
	checks="${checks} $*"
}
