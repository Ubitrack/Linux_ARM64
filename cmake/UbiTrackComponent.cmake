# Adapted from OpenCV CMake Infrastructure, git repository 05/2013
# by Ulrich Eck

# Local variables (set for each component):
#
# name       - short name in lower case i.e. core
# the_component - full name in lower case i.e. utcore

# Global variables:
#
# UBITRACK_COMPONENT_${the_component}_LOCATION
# UBITRACK_COMPONENT_${the_component}_DESCRIPTION
# UBITRACK_COMPONENT_${the_component}_HEADERS
# UBITRACK_COMPONENT_${the_component}_SOURCES
# UBITRACK_COMPONENT_${the_component}_DEPS - final flattened set of component dependencies
# UBITRACK_COMPONENT_${the_component}_DEPS_EXT
# UBITRACK_COMPONENT_${the_component}_REQ_DEPS
# UBITRACK_COMPONENT_${the_component}_OPT_DEPS

# To control the setup of the component you could also set:
# the_description - text to be used as current component description
# UBITRACK_COMPONENT_TYPE - SINGLE|MULTI - set component type to single/multiple

# The verbose template for UbiTrack component:
#
#   ut_add_component(componentname <dependencies>)
#   ut_glob_component_sources() or glob them manually and ut_set_component_sources(...)
#   ut_component_include_directories(<extra include directories>)
#   ut_create_component()
#

# clean components info which needs to be recalculated
set(UBITRACK_COMPONENTS_BUILD          "" CACHE INTERNAL "List of UbiTrack components included into the build")

# adds dependencies to UbiTrack component
# Usage:
#   add_component_dependencies(ubitrack_<name> [REQUIRED] [<list of dependencies>] [OPTIONAL <list of components>])
# Notes:
# * <list of dependencies> - can include full names of components or full pathes to shared/static libraries or cmake targets
macro(ut_add_component_dependencies full_componentname)
  #we don't clean the dependencies here to allow this macro several times for every component
  foreach(d "REQUIRED" ${ARGN})
    if(d STREQUAL "REQUIRED")
      set(__depsvar UBITRACK_COMPONENT_${full_componentname}_DEPS)
    else()
      list(APPEND ${__depsvar} "${d}")
    endif()
  endforeach()
  unset(__depsvar)

  ut_list_unique(UBITRACK_COMPONENT_${full_componentname}_DEPS)

  set(UBITRACK_COMPONENT_${full_componentname}_DEPS ${UBITRACK_COMPONENT_${full_componentname}_DEPS} CACHE INTERNAL "Required dependencies of ${full_componentname} component")
endmacro()

# declare new UbiTrack component in current folder
# Usage:
#   ut_add_component(<name> [DEPS] [<list of dependencies>])
# Example:
#   ut_add_component(utcomponents DEPS utcore utdataflow)
macro(ut_add_component name)
  #string(TOLOWER "${_name}" name)
  set(the_component ${name})

  # the first pass - collect components info, the second pass - create targets
  if(UBITRACK_INITIAL_PASS)
    #guard agains redefinition
    if(";${UBITRACK_COMPONENTS_BUILD};" MATCHES ";${the_component};")
      message(FATAL_ERROR "Redefinition of the ${the_component} component.
  at:                    ${CMAKE_CURRENT_SOURCE_DIR}
  previously defined at: ${UBITRACK_COMPONENT_${the_component}_LOCATION}
")
    endif()

    if(NOT DEFINED the_description)
      set(the_description "The ${name} UbiTrack component")
    endif()

    if(NOT DEFINED BUILD_${the_component}_INIT)
      set(BUILD_${the_component}_INIT ON)
    endif()

    # create option to enable/disable this component
    option(BUILD_${the_component} "Include ${the_component} component into the UbiTrack build" ${BUILD_${the_component}_INIT})

    if(BUILD_${the_component})
      set(UBITRACK_COMPONENTS_BUILD ${UBITRACK_COMPONENTS_BUILD} "${the_component}" CACHE INTERNAL "List of UbiTrack components included into the build")
    endif()

    # remember the component details
    set(UBITRACK_COMPONENT_${the_component}_DESCRIPTION "${the_description}" CACHE INTERNAL "Brief description of ${the_component} component")
    set(UBITRACK_COMPONENT_${the_component}_LOCATION    "${CMAKE_CURRENT_SOURCE_DIR}" CACHE INTERNAL "Location of ${the_component} component sources")
	
    # parse list of dependencies
    if("${ARGV1}" STREQUAL "DEPS")
      set(__ut_argn__ ${ARGN})
      list(REMOVE_AT __ut_argn__ 0)
      ut_add_component_dependencies(${the_component} ${__ut_argn__})
      unset(__ut_argn__)
    endif()

    # stop processing of current file
    return()
  else(UBITRACK_INITIAL_PASS)
    if(NOT BUILD_${the_component})
      return() # extra protection from redefinition
    endif()
    project(${the_component})
  endif(UBITRACK_INITIAL_PASS)
endmacro()

# setup include path for UbiTrack headers for specified component
# ut_module_include_directories(<extra include directories/extra include modules>)
macro(ut_component_include_directories)
  ut_include_directories( "${CMAKE_CURRENT_BINARY_DIR}")
  ut_include_modules(${UBITRACK_COMPONENT_${the_component}_DEPS} ${ARGN})
endmacro()

# sets header and source files for the current component
# NB: all files specified as headers will be installed
# Usage:
# ut_set_component_sources([HEADERS] <list of files> [SOURCES] <list of files>)
macro(ut_set_component_sources)
  set(UBITRACK_COMPONENT_${the_component}_HEADERS "")
  set(UBITRACK_COMPONENT_${the_component}_SOURCES "")

  foreach(f "HEADERS" ${ARGN})
	# ignore filenames, which contain *
	if(f MATCHES "^.*[*].*$")
		# ignore
    elseif(f STREQUAL "HEADERS" OR f STREQUAL "SOURCES")
      set(__filesvar "UBITRACK_COMPONENT_${the_component}_${f}")
    else()
      list(APPEND ${__filesvar} "${f}")
    endif()
  endforeach()

  # the hacky way to embeed any files into the UbiTrack without modification of its build system
  if(COMMAND ut_get_component_external_sources)
    ut_get_component_external_sources()
  endif()

  # use full paths for component to be independent from the component location
  ut_convert_to_full_paths(UBITRACK_COMPONENT_${the_component}_HEADERS)

  set(UBITRACK_COMPONENT_${the_component}_HEADERS ${UBITRACK_COMPONENT_${the_component}_HEADERS} CACHE INTERNAL "List of header files for ${the_component}")
  set(UBITRACK_COMPONENT_${the_component}_SOURCES ${UBITRACK_COMPONENT_${the_component}_SOURCES} CACHE INTERNAL "List of source files for ${the_component}")
endmacro()

# finds and sets headers and sources for the standard UbiTrack component
# Usage:
# ut_glob_component_sources(<extra sources&headers in the same format as used in ut_set_component_sources>)
macro(ut_glob_component_sources)
  set(UBITRACK_COMPONENT_${the_component}_GLOB_HEADERS "")
  set(UBITRACK_COMPONENT_${the_component}_GLOB_SOURCES "")

  foreach(f "HEADERS" ${ARGN})
	if(f STREQUAL "HEADERS" OR f STREQUAL "SOURCES")
      set(__filesvar "UBITRACK_COMPONENT_${the_component}_GLOB_${f}")
    else()
      list(APPEND ${__filesvar} "${f}")
    endif()
  endforeach()
	
	
  file(GLOB lib_srcs ${UBITRACK_COMPONENT_${the_component}_GLOB_SOURCES})
  file(GLOB lib_hdrs ${UBITRACK_COMPONENT_${the_component}_GLOB_HEADERS})
  ut_set_component_sources(HEADERS ${lib_hdrs}
                        SOURCES ${lib_srcs})

  source_group("Src" FILES ${lib_srcs})
  source_group("Include" FILES ${lib_hdrs})
endmacro()

# creates UbiTrack component in current folder
# creates new target, configures standard dependencies, compilers flags, install rules
# Usage:
#   ut_create_multi_component(<extra link dependencies>)
macro(ut_create_multi_component)
	foreach(fpath ${UBITRACK_COMPONENT_${the_component}_SOURCES})
		GET_FILENAME_COMPONENT(fname ${fpath} NAME_WE)

		add_library(${fname} SHARED ${UBITRACK_COMPONENT_${the_component}_HEADERS} ${fpath})

		#MESSAGE(STATUS "${the_component} ${UBITRACK_COMPONENT_${the_component}_DEPS} ${UBITRACK_COMPONENT_${the_component}_DEPS_EXT} ${UBITRACK_LINKER_LIBS} ${IPP_LIBS} ${ARGN}")
		target_link_libraries(${fname} ${UBITRACK_COMPONENT_${the_component}_DEPS} ${UBITRACK_COMPONENT_${the_component}_DEPS_EXT} ${UBITRACK_LINKER_LIBS} ${IPP_LIBS} ${ARGN})

		set_target_properties(${fname} PROPERTIES
		  OUTPUT_NAME "${fname}"
		  DEBUG_POSTFIX "${UBITRACK_DEBUG_POSTFIX}"
		  ARCHIVE_OUTPUT_DIRECTORY ${UBITRACK_COMPONENT_INSTALL_PATH}
		  LIBRARY_OUTPUT_DIRECTORY ${UBITRACK_COMPONENT_INSTALL_PATH}
		  RUNTIME_OUTPUT_DIRECTORY ${EXECUTABLE_OUTPUT_PATH}
		  INSTALL_NAME_DIR lib
		)

		# For dynamic link numbering convenions
		#if(NOT ANDROID)
		#  # Android SDK build scripts can include only .so files into final .apk
		#  # As result we should not set version properties for Android
		#  set_target_properties(${fname} PROPERTIES
		#    VERSION ${UBITRACK_LIBVERSION}
		#    SOVERSION ${UBITRACK_SOVERSION}
		#  )
		#endif()

		if(BUILD_SHARED_LIBS)
		  if(MSVC)
			  set_target_properties(${fname} PROPERTIES COMPILE_FLAGS "${UBITRACK_COMPILE_FLAGS}")
			  set_target_properties(${fname} PROPERTIES LINK_FLAGS "${UBITRACK_LINK_FLAGS}")
			  foreach(_symb ${UBITRACK_DEFINES})
				  set_target_properties(${fname} PROPERTIES DEFINE_SYMBOL ${_symb})
			  endforeach()
		  endif()
		endif()

		if(MSVC)
		  if(CMAKE_CROSSCOMPILING)
		    set_target_properties(${fname} PROPERTIES LINK_FLAGS "/NODEFAULTLIB:secchk")
		  endif()
		  set_target_properties(${fname} PROPERTIES LINK_FLAGS "/NODEFAULTLIB:libc /DEBUG")
		endif()

		install(TARGETS ${fname}
		  RUNTIME DESTINATION ${UBITRACK_COMPONENT_BIN_INSTALL_PATH} COMPONENT main
		  LIBRARY DESTINATION ${UBITRACK_COMPONENT_INSTALL_PATH} COMPONENT main
		  ARCHIVE DESTINATION ${UBITRACK_COMPONENT_INSTALL_PATH} COMPONENT main
		  )

	 endforeach()

endmacro()

# creates UbiTrack component in current folder
# creates new target, configures standard dependencies, compilers flags, install rules
# Usage:
#   ut_create_single_component(<extra link dependencies>)
macro(ut_create_single_component)
	add_library(${the_component} SHARED ${UBITRACK_COMPONENT_${the_component}_HEADERS} ${UBITRACK_COMPONENT_${the_component}_SOURCES})

	#MESSAGE(STATUS "${the_component} ${UBITRACK_COMPONENT_${the_component}_DEPS} ${UBITRACK_COMPONENT_${the_component}_DEPS_EXT} ${UBITRACK_LINKER_LIBS} ${IPP_LIBS} ${ARGN}")
	target_link_libraries(${the_component} ${UBITRACK_COMPONENT_${the_component}_DEPS} ${UBITRACK_COMPONENT_${the_component}_DEPS_EXT} ${UBITRACK_LINKER_LIBS} ${IPP_LIBS} ${ARGN})

	set_target_properties(${the_component} PROPERTIES
	  OUTPUT_NAME "${the_component}"
	  DEBUG_POSTFIX "${UBITRACK_DEBUG_POSTFIX}"
	  ARCHIVE_OUTPUT_DIRECTORY ${UBITRACK_COMPONENT_INSTALL_PATH}
	  LIBRARY_OUTPUT_DIRECTORY ${UBITRACK_COMPONENT_INSTALL_PATH}
	  RUNTIME_OUTPUT_DIRECTORY ${EXECUTABLE_OUTPUT_PATH}
	  INSTALL_NAME_DIR lib
	)

	# For dynamic link numbering convenions
	#if(NOT ANDROID)
	#  # Android SDK build scripts can include only .so files into final .apk
	#  # As result we should not set version properties for Android
	#  set_target_properties(${the_component} PROPERTIES
	#    VERSION ${UBITRACK_LIBVERSION}
	#    SOVERSION ${UBITRACK_SOVERSION}
	#  )
	#endif()

	if(BUILD_SHARED_LIBS)
	  if(MSVC)
		  set_target_properties(${the_component} PROPERTIES COMPILE_FLAGS "${UBITRACK_COMPILE_FLAGS}")
		  set_target_properties(${the_component} PROPERTIES LINK_FLAGS "${UBITRACK_LINK_FLAGS}")
		  foreach(_symb ${UBITRACK_DEFINES})
			  set_target_properties(${the_component} PROPERTIES DEFINE_SYMBOL ${_symb})
		  endforeach()
	  endif()
	endif()

	if(MSVC)
	  if(CMAKE_CROSSCOMPILING)
	    set_target_properties(${the_component} PROPERTIES LINK_FLAGS "/NODEFAULTLIB:secchk")
	  endif()
	  set_target_properties(${the_component} PROPERTIES LINK_FLAGS "/NODEFAULTLIB:libc /DEBUG")
	endif()

	install(TARGETS ${the_component}
	  RUNTIME DESTINATION ${UBITRACK_COMPONENT_BIN_INSTALL_PATH} COMPONENT main
	  LIBRARY DESTINATION ${UBITRACK_COMPONENT_INSTALL_PATH} COMPONENT main
	  ARCHIVE DESTINATION ${UBITRACK_COMPONENT_INSTALL_PATH} COMPONENT main
	  )

endmacro()