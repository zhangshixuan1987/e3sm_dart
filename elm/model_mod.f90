! DART software - Copyright UCAR. This open source software is provided
! by UCAR, "as is", without charge, subject to all terms of use at
! http://www.image.ucar.edu/DAReS/DART/DART_download
!

module model_mod

! DART interface module for the E3SM Land Model (ELM).
! Placeholder stub - copy the required interfaces from
! DART/models/template/model_mod.f90 and implement ELM-specific code here.

use        types_mod, only : r8, i8, MISSING_R8

use time_manager_mod, only : time_type, set_time

use     location_mod, only : location_type, get_close_type, &
                             loc_get_close_obs => get_close_obs, &
                             loc_get_close_state => get_close_state, &
                             set_location, set_location_missing

use    utilities_mod, only : error_handler, &
                             E_ERR, E_MSG, &
                             nmlfileunit, do_output, do_nml_file, do_nml_term,  &
                             find_namelist_in_file, check_namelist_read

use netcdf_utilities_mod, only : nc_add_global_attribute, nc_synchronize_file, &
                                 nc_add_global_creation_time, &
                                 nc_begin_define_mode, nc_end_define_mode

use state_structure_mod, only : add_domain, get_domain_size

use ensemble_manager_mod, only : ensemble_type

use default_model_mod, only : pert_model_copies, read_model_time, write_model_time, &
                              init_time => fail_init_time, &
                              init_conditions => fail_init_conditions, &
                              nc_write_model_vars

implicit none
private

public :: get_model_size,         &
          get_state_meta_data,    &
          model_interpolate,      &
          shortest_time_between_assimilations, &
          static_init_model,      &
          init_conditions,        &
          init_time,              &
          adv_1step,              &
          end_model,              &
          nc_write_model_atts,    &
          nc_write_model_vars,    &
          pert_model_copies,      &
          get_close_obs,          &
          get_close_state,        &
          read_model_time,        &
          write_model_time

character(len=256), parameter :: source = 'elm/model_mod.f90'

contains

subroutine static_init_model()
call error_handler(E_ERR, 'static_init_model', 'ELM model_mod not yet implemented', source)
end subroutine static_init_model

end module model_mod
