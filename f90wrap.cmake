#==============================================================
# Function to run f90wrap on a list of source files
#==============================================================

function (run_f90wrap compiler src_list proj moddir libs locs outpath)

#==============================================================
# First step: make directory to place f90wrap-generated files
#==============================================================

  SET(subdir f90wrap)
  SET(path ${BIN}/${proj})
  IF(EXISTS ${path})
  ELSE()
    FILE(MAKE_DIRECTORY ${path})
  ENDIF(EXISTS ${path})

  set(wrapdir ${path}/${subdir})
  IF(EXISTS ${wrapdir})
  ELSE()
    FILE(MAKE_DIRECTORY ${wrapdir})
  ENDIF(EXISTS ${wrapdir})

#==============================================================
# Include nested function definitions
#==============================================================

  INCLUDE(${CMAKE_MODULE_PATH}/Preprocess_definition.cmake) 

#==============================================================
# Identify compiler and set flags
#==============================================================
  
  MESSAGE(${compiler} " is the compiler")
  id_flags("${compiler}" "${flags}" "${PAR_FLAG}" "${OMP}" "${CN}" "${EXT}")

#==============================================================
# Build list of preprocessed file names
#==============================================================

  set(file_list "")
  set(subfolder ${proj}/${subdir})
  set(flags2 ${flags})
#==============================================================
# loop over files that need to be integrated with python
#==============================================================

  FOREACH(filename ${src_list})

#==============================================================
# Run the preprocessor using the compiler
#==============================================================

    preprocess(${filename} "${flags2}" "${subfolder}" "${EXT}")  

#==============================================================
# copy the filename into a temp variable
# (dunno if you can change cmake iterators)
#==============================================================

    set(file ${filename})

#==============================================================
# Change the extension and add it to a new list
#==============================================================

    change_extension(${file} ${EXT} "${subfolder}")
    LIST(APPEND file_list ${file})

  ENDFOREACH(filename)

#==============================================================
# Add custom target (dummy tag PREPROC) that tells CMake that 
# ${file_list} is the list of dependencies needed to make it 
# Without this custom target, the preprocessor will not run
#==============================================================

  add_custom_target(
    PREPROC_${prj} 
    DEPENDS ${file_list}
    COMMENT "Preprocessing file"
    VERBATIM)

#==============================================================
# Now create CMake commands to run f90wrap
#==============================================================

#==============================================================
# Step 2: run f90wrap on source files to create API defs in .py
#==============================================================

  set(output ${path}/${proj}.py)
  set(outpt2 ${path}/${proj})
#MESSAGE("OUTPUT OF STAGE 1 F90wrap is " ${output})
  set(kmap_file ${CMAKE_MODULE_PATH}/kind_map)

#==============================================================
# Add a custom command for running f90wrap
#==============================================================

  add_custom_command(

#==============================================================
# Define the output
#==============================================================

    OUTPUT ${output}

#==============================================================
# Command is use the fortran compiler with the flags given on 
# the filename specified, pass everything verbatim
#==============================================================

    COMMAND f90wrap -m ${proj} ${file_list} -k ${kmap_file} -v
    COMMENT "CREATING PYTHON MODULE" ${output}
    WORKING_DIRECTORY ${path}
    )

#==============================================================
# f90wrap-created python module is target
#==============================================================
  
  LIST(GET libs 0 first_lib) 
  add_custom_target(
    API_${prj} ALL
    DEPENDS PREPROC_${prj} ${output} ${file_list} ${first_lib}
    COMMENT "creating python API"
    VERBATIM)

#==============================================================
# Step 3: run f2py-f90wrap to create shared object
#==============================================================

  set(SO _${proj}.so)                                   # shared object name
#MESSAGE("DIRECTORY IS " ${wrapdir})                # print message

  set(f90src f90wrap_*.f90)

#==============================================================
# Add list of libraries and locations for f90wrap visibility
#==============================================================

#==============================================================
# First check whether #libraries <= #paths
#==============================================================

  LIST(LENGTH libs len)
  LIST(LENGTH locs ln2)
  message("LENGTH OF LIST IS " ${len} "," ${ln2})

  if(${len} GREATER ${ln2} AND ${len} GREATER 0)
    MESSAGE("CRITICAL ERROR")
    MESSAGE(${len} " LIBRARIES ARE " ${libs})
    MESSAGE(${ln2} " LOCATIONS ARE " ${locs})
    MESSAGE(FATAL ERROR "CANNOT PROCEED: number of libraries exceeds number of paths ")
  endif()

#==============================================================
# IF error trap is not triggered, create list of library links
#==============================================================

  set(f90wrap_links "")
  MATH(EXPR ln2 "${ln2}-1")
  MESSAGE("list length is " ${ln2})
  foreach(val RANGE ${ln2})
    list(GET libs ${val} lib_name)
    list(GET locs ${val} lib_path)
    message(STATUS "ADDING LIBRARY ${lib_name} IN LOCATION \n ${lib_path}")
    LIST(APPEND f90wrap_links -L${lib_path} -l${lib_name})
  endforeach()
  LIST(APPEND f90wrap_links ${f90src})

#==============================================================
# Fortran compilation options
#==============================================================

  set(f90wrap_options --fcompiler=${CN} --f90flags=${PAR_FLAG} ${OMP} -I${moddir} --build-dir . --quiet)

#==============================================================
# Add a custom command for running f90wrap
#==============================================================

  add_custom_command(

    OUTPUT ${SO}        # Define the output

#==============================================================
# Command is use the fortran compiler with the flags given on 
# the filename specified, pass everything verbatim
#==============================================================

    COMMENT ("CREATING SHARED OBJECT" ${SO})
    COMMAND f2py-f90wrap -c -m _${proj} ${f90wrap_links} ${f90wrap_options} #-v
    WORKING_DIRECTORY ${path}
  )

  add_custom_target(
    SHAREDOBJECT_${prj} ALL
    DEPENDS ${SO} API_${prj} 
    COMMENT "creating shared object"
    VERBATIM)

#==============================================================
# Link libraries to target
#==============================================================

#  TARGET_LINK_LIBRARIES(SHAREDOBJECT_${prj} ${libs})

#==============================================================
  
  set(PY ${proj}.py)
  add_custom_command(TARGET SHAREDOBJECT_${prj}
                   POST_BUILD
                   COMMAND ${CMAKE_COMMAND} -E copy ${SO} ${outpath}
                   WORKING_DIRECTORY ${path})

  add_custom_command(TARGET API_${prj}
                   POST_BUILD
                   COMMAND ${CMAKE_COMMAND} -E copy ${PY} ${outpath}
                   WORKING_DIRECTORY ${path})

endfunction()
