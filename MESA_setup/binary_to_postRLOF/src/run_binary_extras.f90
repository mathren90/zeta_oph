! ***********************************************************************
!
!   Copyright (C) 2012-2019  Bill Paxton & The MESA Team
!
!   this file is part of mesa.
!
!   mesa is free software; you can redistribute it and/or modify
!   it under the terms of the gnu general library public license as published
!   by the free software foundation; either version 2 of the license, or
!   (at your option) any later version.
!
!   mesa is distributed in the hope that it will be useful,
!   but without any warranty; without even the implied warranty of
!   merchantability or fitness for a particular purpose.  see the
!   gnu library general public license for more details.
!
!   you should have received a copy of the gnu library general public license
!   along with this software; if not, write to the free software
!   foundation, inc., 59 temple place, suite 330, boston, ma 02111-1307 usa
!
! ***********************************************************************
      module run_binary_extras

      use star_lib
      use star_def
      use const_def
      use const_def
      use chem_def
      use num_lib
      use binary_def
      use math_lib

      implicit none

      contains

      subroutine extras_binary_controls(binary_id, ierr)
         integer :: binary_id
         integer, intent(out) :: ierr
         type (binary_info), pointer :: b
         ierr = 0

         call binary_ptr(binary_id, b, ierr)
         if (ierr /= 0) then
            write(*,*) 'failed in binary_ptr'
            return
         end if

         ! Set these function pointers to point to the functions you wish to use in
         ! your run_binary_extras. Any which are not set, default to a null_ version
         ! which does nothing.
         b% how_many_extra_binary_history_header_items => how_many_extra_binary_history_header_items
         b% data_for_extra_binary_history_header_items => data_for_extra_binary_history_header_items
         b% how_many_extra_binary_history_columns => how_many_extra_binary_history_columns
         b% data_for_extra_binary_history_columns => data_for_extra_binary_history_columns

         b% extras_binary_startup=> extras_binary_startup
         b% extras_binary_start_step=> extras_binary_start_step
         b% extras_binary_check_model=> extras_binary_check_model
         b% extras_binary_finish_step => extras_binary_finish_step
         b% extras_binary_after_evolve=> extras_binary_after_evolve

         ! Once you have set the function pointers you want, then uncomment this (or set it in your star_job inlist)
         ! to disable the printed warning message,
          b% warn_binary_extra =.false.

      end subroutine extras_binary_controls


      integer function how_many_extra_binary_history_header_items(binary_id)
         use binary_def, only: binary_info
         integer, intent(in) :: binary_id
         how_many_extra_binary_history_header_items = 0
      end function how_many_extra_binary_history_header_items


      subroutine data_for_extra_binary_history_header_items( &
           binary_id, n, names, vals, ierr)
         type (binary_info), pointer :: b
         integer, intent(in) :: binary_id, n
         character (len=maxlen_binary_history_column_name) :: names(n)
         real(dp) :: vals(n)
         integer, intent(out) :: ierr
         ierr = 0
         call binary_ptr(binary_id, b, ierr)
         if (ierr /= 0) then
            write(*,*) 'failed in binary_ptr'
            return
         end if
      end subroutine data_for_extra_binary_history_header_items


      integer function how_many_extra_binary_history_columns(binary_id)
         use binary_def, only: binary_info
         integer, intent(in) :: binary_id
         how_many_extra_binary_history_columns = 0
      end function how_many_extra_binary_history_columns


      subroutine data_for_extra_binary_history_columns(binary_id, n, names, vals, ierr)
         type (binary_info), pointer :: b
         integer, intent(in) :: binary_id
         integer, intent(in) :: n
         character (len=maxlen_binary_history_column_name) :: names(n)
         real(dp) :: vals(n)
         integer, intent(out) :: ierr
         ierr = 0
         call binary_ptr(binary_id, b, ierr)
         if (ierr /= 0) then
            write(*,*) 'failed in binary_ptr'
            return
         end if

      end subroutine data_for_extra_binary_history_columns


      integer function extras_binary_startup(binary_id,restart,ierr)
         type (binary_info), pointer :: b
         integer, intent(in) :: binary_id
         integer, intent(out) :: ierr
         logical, intent(in) :: restart
         call binary_ptr(binary_id, b, ierr)
         if (ierr /= 0) then ! failure in  binary_ptr
            return
         end if

         ! b% s1% job% warn_run_star_extras = .false.

         b% lxtra(1) = .false. ! flag for end of donor's main sequence
         b% lxtra(2) = .false. ! flag for beginning RLOF
         b% lxtra_old(2) = .false.

         extras_binary_startup = keep_going

       end function  extras_binary_startup

      integer function extras_binary_start_step(binary_id,ierr)
         type (binary_info), pointer :: b
         integer, intent(in) :: binary_id
         integer, intent(out) :: ierr

         extras_binary_start_step = keep_going
         call binary_ptr(binary_id, b, ierr)
         if (ierr /= 0) then ! failure in  binary_ptr
            return
         end if
      end function  extras_binary_start_step

      !Return either keep_going, retry or terminate
      integer function extras_binary_check_model(binary_id)
         type (binary_info), pointer :: b
         integer, intent(in) :: binary_id
         integer :: ierr
         call binary_ptr(binary_id, b, ierr)
         if (ierr /= 0) then ! failure in  binary_ptr
            return
         end if
         extras_binary_check_model = keep_going

      end function extras_binary_check_model


      ! returns either keep_going or terminate.
      ! note: cannot request retry; extras_check_model can do that.
      integer function extras_binary_finish_step(binary_id)
         type (binary_info), pointer :: b
         integer, intent(in) :: binary_id
         integer :: ierr
         character (len=200) :: fname
         call binary_ptr(binary_id, b, ierr)
         if (ierr /= 0) then ! failure in  binary_ptr
            return
         end if
         extras_binary_finish_step = keep_going

         ! find beginning RLOF
         if ((b% lxtra(2) .eqv. .false.) .and. &
              (b% lxtra_old(2) .eqv. .false.)) then
            ! RLOF has not started before
            if (b% rl_relative_gap(b% d_i) > 0) then
               write(fname, fmt="(a20)") 'donor_onset_RLOF.mod'
               call star_write_model(b% star_ids(1), fname, ierr)
               write(fname, fmt="(a23)") 'accretor_onset_RLOF.mod'
               call star_write_model(b% star_ids(2), fname, ierr)
               print *, "Beginning of RLOF", b% lxtra(2), b% lxtra_old(2)
               b% lxtra(2) = .true.
               b% lxtra_old(2) = .true.
            end if
         end if

         ! find donor's TAMS
         if ((b% s_donor% xa(b% s_donor% net_iso(ih1), b% s_donor% nz) < 1d-4) .and. &
              (b% lxtra(1) .eqv. .false.)) then
            b% lxtra(1) =.true.
            b% xtra(1) = b% s_donor% r(1)
            print *, "saved donor radius at TAMS", b% xtra(1)
            write(fname, fmt="(a14)") 'donor_TAMS.mod'
            call star_write_model(b% star_ids(1), fname, ierr)
         end if

         ! stop at the end case B RLOF
         if ((b% s_donor% surface_he4 > 0.35d0) .and. & ! donor is He rich
              (b% rl_relative_gap(b% d_i) < 0) .and. &  ! donor is detached
              (b% s_donor% r(1) < b% xtra(1))) then     ! donor's radius smaller than TAMS radius
            ! save model for the donor
            print *, "save models after (case B) RLOF"
            write(fname, fmt="(a18)") 'donor_postRLOF.mod'
            call star_write_model(b% star_ids(1), fname, ierr)
            if (ierr /= 0) return
            ! save model for the accretor
            write(fname, fmt="(a21)") 'accretor_postRLOF.mod'
            call star_write_model(b% star_ids(2), fname, ierr)
            if (ierr /= 0) return
            ! reset radius at TAMS to a negative value so we don't override the postRLOF models
            b% xtra(1) = -1

            if (b% s_donor% x_logical_ctrl(1) .eqv. .true.) then
               print *, "Donor is HE rich and significantly detached, gonna stop now!"
               print *, "termination code: RLOF detachment"
               extras_binary_finish_step = terminate
            end if
         end if

      end function extras_binary_finish_step

      subroutine extras_binary_after_evolve(binary_id, ierr)
         type (binary_info), pointer :: b
         integer, intent(in) :: binary_id
         integer, intent(out) :: ierr
         call binary_ptr(binary_id, b, ierr)
         if (ierr /= 0) then ! failure in  binary_ptr
            return
         end if


      end subroutine extras_binary_after_evolve

      end module run_binary_extras
