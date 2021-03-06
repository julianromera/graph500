# ax-ccc-warnings.m4
#
# serial 3
#

dnl AX_CC_WARNINGS
dnl Turn on many useful compiler warnings and substitute the result into
dnl WARN_CFLAGS
dnl For now, only works on GCC
dnl Pass the default value of the --enable-cc-warnings configure option as
dnl the first argument to the macro, defaulting to 'yes'.
dnl Additional warning/error flags can be passed as an optional second argument.
dnl
dnl For example: AX_CC_WARNINGS([maximum],[-Werror=some-flag -Wfoobar])
AC_DEFUN([AX_CC_WARNINGS],[
    dnl ******************************
    dnl More compiler warnings
    dnl ******************************

    AC_ARG_ENABLE(cc-warnings, 
                  AC_HELP_STRING([--enable-cc-warnings=<no|minimum|yes|maximum|error>],
                                 [Turn on C compiler warnings. Default selection si maximum]),,
                  [enable_cc_warnings="m4_default([$1],[yes])"])

    if test "x$GCC" != xyes; then
	enable_cc_warnings=no
    fi

    warning_flags=
    realsave_CFLAGS="$CFLAGS"

    dnl These are warning flags that aren't marked as fatal.  Can be
    dnl overridden on a per-project basis with -Wno-foo.
    base_warn_flags=" \
        -Wall \
        -Wstrict-prototypes \
        -Wnested-externs \
    "

    dnl These compiler flags typically indicate very broken or suspicious
    dnl code.  Some of them such as implicit-function-declaration are
    dnl just not default because gcc compiles a lot of legacy code.
    dnl We choose to make this set into explicit errors.
    base_error_flags=" \
        dnl -Werror=missing-prototypes \
        -Werror=implicit-function-declaration \
        -Werror=pointer-arith \
        -Werror=init-self \
        -Werror=format-security \
        -Werror=format=2 \
        -Werror=missing-include-dirs \
    "

    dnl Additional warning or error flags provided by the module author to
    dnl allow stricter standards to be imposed on a per-module basis.
    dnl The author can pass -W or -Werror flags here as they see fit.
    additional_flags="m4_default([$2],[])"

    case "$enable_cc_warnings" in
    no)
        warning_flags=
        ;;
    minimum)
        warning_flags="-Wall"
        ;;
    yes)
        warning_flags="$base_warn_flags $base_error_flags $additional_flags"
        ;;
    maximum|error)
        warning_flags="$base_warn_flags $base_error_flags $additional_flags"
        ;;
    *)
        AC_MSG_ERROR(Unknown argument '$enable_cc_warnings' to --enable-cc-warnings)
        ;;
    esac

    if test "$enable_cc_warnings" = "error" ; then
        warning_flags="$warning_flags -Werror"
    fi

    dnl Check whether GCC supports the warning options
    for option in $warning_flags; do
	save_CFLAGS="$CFLAGS"
	CFLAGS="$CFLAGS $option"
	AC_MSG_CHECKING([whether C understands $option])
	AC_TRY_COMPILE([], [],
	    has_option=yes,
	    has_option=no,)
	CFLAGS="$save_CFLAGS"
	AC_MSG_RESULT([$has_option])
	if test $has_option = yes; then
	    tested_warning_flags="$tested_warning_flags $option"
	fi
	unset has_option
	unset save_CFLAGS
    done
    unset option
    CFLAGS="$realsave_CFLAGS"
    AC_MSG_CHECKING(what warning flags to pass to the C compiler)
    AC_MSG_RESULT($tested_warning_flags)

    AC_ARG_ENABLE(iso-c,
                  AC_HELP_STRING([--enable-iso-c],
                                 [Try to warn if code is not ISO C ]),,
                  [enable_iso_c=no])

    AC_MSG_CHECKING(what language compliance flags to pass to the C compiler)
    complCFLAGS=
    if test "x$enable_iso_c" != "xno"; then
	if test "x$GCC" = "xyes"; then
	case " $CFLAGS " in
	    *[\ \	]-ansi[\ \	]*) ;;
	    *) complCFLAGS="$complCFLAGS -ansi" ;;
	esac
	case " $CFLAGS " in
	    *[\ \	]-pedantic[\ \	]*) ;;
	    *) complCFLAGS="$complCFLAGS -pedantic" ;;
	esac
	fi
    fi
    AC_MSG_RESULT($complCFLAGS)

    WARN_CFLAGS="$tested_warning_flags $complCFLAGS"
    AC_SUBST(WARN_CFLAGS)
    unset tested_warning_flags
])
