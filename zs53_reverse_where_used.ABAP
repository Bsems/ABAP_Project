*&---------------------------------------------------------------------*
*& Report ZS53_REVERSE_WHERE_USED
*&---------------------------------------------------------------------*
*&
*&---------------------------------------------------------------------*
REPORT zs53_reverse_where_used.

TABLES: tadir, tdevc.



SELECT-OPTIONS:
  so_devc FOR tadir-devclass,
  so_type FOR tadir-object,
  so_name FOR tadir-obj_name.

SELECTION-SCREEN ULINE.

SELECT-OPTIONS:
  sl_type FOR tadir-object,
  sl_name FOR tadir-obj_name,
  sl_devc FOR tadir-devclass,
  sl_soft FOR tdevc-dlvunit DEFAULT 'HOME'.

*INCLUDE zs53_reverse_where_used_top.
*INCLUDE zs53_reverse_where_used_frm.


" DATA DECLARATION
TYPES : BEGIN OF gy_tadir,
          pgmid    TYPE tadir-pgmid,
          object   TYPE tadir-object,
          obj_name TYPE tadir-obj_name,
          author   TYPE tadir-author,
          devclass TYPE tadir-devclass,
*          soft     TYPE tdevc-dlvunit,
        END OF gy_tadir.

TYPES: gyt_tadir TYPE SORTED TABLE OF gy_tadir WITH UNIQUE KEY pgmid object obj_name.
TYPES: gyr_include TYPE RANGE OF wbcrossgt-include.


START-OF-SELECTION.


  DATA: it_tadir TYPE gyt_tadir,
        gt_full  TYPE gyt_tadir.

  PERFORM get_initial CHANGING it_tadir.
  DATA(gt_result) = it_tadir.

  DO.
    PERFORM expend_tadir CHANGING it_tadir gt_result.
    PERFORM remove_out_of_boundaries CHANGING gt_result.
    PERFORM remove_already_processed USING gt_full CHANGING gt_result.

    IF gt_result IS INITIAL.
      EXIT.
    ELSE.
      it_tadir = gt_result.
    ENDIF.
    PERFORM add_result USING gt_result CHANGING gt_full.
  ENDDO.
  PERFORM write_result USING gt_full.




  "FORMS

*&---------------------------------------------------------------------*
*&      Form  GET_INITIAL
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      <--P_IT_TADIR  text
*----------------------------------------------------------------------*
FORM get_initial  CHANGING p_it_tadir TYPE gyt_tadir.

  IF so_type[] IS NOT INITIAL.
    DATA(lv_query) = 'object IN so_type'.
  ENDIF.

  IF so_name[] IS NOT INITIAL.
    CONCATENATE lv_query 'AND name IN so_name[]' INTO lv_query SEPARATED BY space.
  ENDIF.

  IF so_devc IS NOT INITIAL.
    CONCATENATE lv_query 'AND devclas IN so_devc[]' INTO lv_query SEPARATED BY space.
  ENDIF.

  IF so_devc IS NOT INITIAL.
    CONCATENATE lv_query 'AND dlvunit IN @sl_soft[]' INTO lv_query SEPARATED BY space.
  ENDIF.

  IF lv_query IS NOT INITIAL.
    SELECT pgmid object obj_name author devclass
      FROM tadir
      INTO TABLE p_it_tadir
      WHERE (lv_query).

" New method for the dynamic selection
*lv_where = ||.
*
*  IF so_type[] IS NOT INITIAL.
*    lv_where = |object IN @so_type|.
*  ENDIF.

*  IF so_name[] IS NOT INITIAL.
*    lv_where = cond #( 
*      WHEN lv_where IS INITIAL THEN |obj_name IN @so_name|
*      ELSE |{ lv_where } AND obj_name IN @so_name|
*    ).
*  ENDIF.
*
*  IF so_devc[] IS NOT INITIAL.
*    lv_where = cond #( 
*      WHEN lv_where IS INITIAL THEN |devclass IN @so_devc|
*      ELSE |{ lv_where } AND devclass IN @so_devc|
*    ).
*  ENDIF.
*
*  IF sl_soft[] IS NOT INITIAL.
*    lv_where = cond #( 
*      WHEN lv_where IS INITIAL THEN |dlvunit IN @sl_soft|
*      ELSE |{ lv_where } AND dlvunit IN @sl_soft|
*    ).
*  ENDIF.
  ENDIF.
ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  REMOVE_OUT_OF_BOUNDARIES
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      <--P_GT_RESULT  text
*----------------------------------------------------------------------*
FORM remove_out_of_boundaries  CHANGING p_gt_result TYPE gyt_tadir.

  DATA : lr_bound TYPE RANGE OF tdevc-dlvunit.

  IF p_gt_result IS NOT INITIAL.
    IF sl_type IS NOT INITIAL.
      DELETE p_gt_result WHERE object IN sl_type .
    ENDIF.
    IF sl_name IS NOT INITIAL.
      DELETE p_gt_result WHERE obj_name IN sl_name.
    ENDIF.
    IF sl_devc IS NOT INITIAL.
      DELETE p_gt_result WHERE devclass IN sl_devc.
    ENDIF.
    IF sl_soft IS NOT INITIAL.
      " Get packages linked to the software component
      SELECT devclass, dlvunit
        FROM tdevc
        FOR ALL ENTRIES IN @p_gt_result
        WHERE devclass = @p_gt_result-devclass
        AND   dlvunit  IN @sl_soft
        INTO TABLE @DATA(lt_boundries).

      " Delete found values from gt_result
      lr_bound = VALUE #( FOR ls_bound IN lt_boundries ( sign = rs_c_range_sign-including
                                                         option = rs_c_range_opt-equal
                                                         low = ls_bound-devclass ) ).
*  DELETE p_gt_result FROM lt_boundries WHERE devclass = devclass.
      DELETE p_gt_result WHERE devclass IN lr_bound.
    ENDIF.
  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  REMOVE_ALREADY_PROCESSED
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      -->P_GT_FULL  text
*      <--P_GT_RESULT  text
*----------------------------------------------------------------------*
FORM remove_already_processed  USING    p_gt_full   TYPE gyt_tadir
                               CHANGING p_gt_result TYPE gyt_tadir.

*Remove entries from p_gt_result that are already in p_gt_full
  p_gt_result = FILTER #(
    p_gt_result EXCEPT IN p_gt_full
    WHERE pgmid = pgmid AND
          object = object AND
          obj_name = obj_name ).

ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  ADD_RESULT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      <--P_GT_FULL  text
*----------------------------------------------------------------------*
FORM add_result  USING p_gt_result TYPE gyt_tadir
                 CHANGING p_gt_full TYPE gyt_tadir.

  INSERT LINES OF p_gt_result INTO TABLE gt_full.


ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  WRITE_RESULT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      -->P_GT_FULL  text
*----------------------------------------------------------------------*
FORM write_result  USING    p_gt_full TYPE gyt_tadir.

  LOOP AT p_gt_full ASSIGNING FIELD-SYMBOL(<fs_gt_full>).
    WRITE: / <fs_gt_full>-object ,<fs_gt_full>-obj_name.
  ENDLOOP.
*  cl_demo_output=>display( p_gt_full ).

ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  EXPEND_TADIR
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      <--P_IT_TADIR  text
*      <--P_GT_RESULT  text
*----------------------------------------------------------------------*
FORM expend_tadir  CHANGING p_it_tadir TYPE  gyt_tadir
                            p_gt_result TYPE gyt_tadir.

  DATA: lr_prog_include TYPE gyr_include,
        lr_fugr_include TYPE gyr_include,
        lr_include      TYPE gyr_include.

  " For class
  PERFORM expend_clas USING p_it_tadir.


  " For program
  PERFORM expend_prog USING p_it_tadir CHANGING lr_include.

  " For function groups
  PERFORM expend_fugr USING p_it_tadir CHANGING lr_fugr_include.

  PERFORM find_match USING lr_include.

  "Unique range to append ?
  "Check validity of includes in TRDIR ?
ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  EXPEND_PROG
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      -->P_IT_TADIR  text
*      -->P_LR_PROG_INCLUDE text
*----------------------------------------------------------------------*
FORM expend_prog USING p_it_tadir TYPE  gyt_tadir
                 CHANGING p_lr_include TYPE gyr_include.



*  p_lr_prog_include = VALUE #( FOR ls_it_tadir IN p_it_tadir WHERE ( object = 'PROG' )
*                                                      ( sign = rs_c_range_sign-including
*                                                      option = rs_c_range_opt-equal
*                                                      low = ls_it_tadir-obj_name ) ).
  APPEND LINES OF VALUE gyr_include(
  FOR ls_it_tadir IN p_it_tadir
  WHERE ( object = 'PROG' )
    ( sign   = rs_c_range_sign-including
      option = rs_c_range_opt-equal
      low    = ls_it_tadir-obj_name )
      ) TO p_lr_include.

ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  EXPEND_CLAS
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      -->P_P_IT_TADIR  text
*----------------------------------------------------------------------*
FORM expend_clas  USING    p_p_it_tadir TYPE  gyt_tadir.
  " Use class CL_OO_CLASSNAME_SERVICE to get the includes related to a class/interface
  " To get all includes, method GET_ALL_CLASS_INCLUDES() can be called. Otherwise call individual methods
  " For later read in tables CROSS/WBCROSSGT, some includes are not needed CP/CI...
  " These methods are not called in mass: how to manage ? Is it ok to loop at it_tadir ?
  " How to append list of includes in final list ?

  DATA: lt_includes       TYPE RANGE OF progname,
        lt_class_includes TYPE STANDARD TABLE OF progname,
        lv_classname      TYPE tadir-obj_name,
        lv_lenght         TYPE i,
        lv_include        TYPE progname.


  CLEAR lt_includes.

  LOOP AT p_p_it_tadir ASSIGNING FIELD-SYMBOL(<ls_tadir>) WHERE object = 'CLAS' OR object = 'INTF'.
    CLEAR : lt_class_includes, lv_lenght.


*    lv_lenght = strlen( <ls_tadir>-obj_name ).

*
*    DO 30 - lv_lenght TIMES.
*      <lv_include> = <ls_tadir>-obj_name && '='.
*    ENDDO.
*
*    <lv_include> = <lv_include> && 'C*'.


    lv_include =  <ls_tadir>-obj_name && repeat( val = '=' occ = 30 - strlen( <ls_tadir>-obj_name ) ) && 'C*'.


    APPEND VALUE #( sign = 'I' option = 'EQ' low = lv_include ) TO lt_includes.

  ENDLOOP.

* Remove duplicates from range table
  SORT lt_includes BY low.
  DELETE ADJACENT DUPLICATES FROM lt_includes COMPARING low.

* Read WBCROSSGT using the range table
*  SELECT * FROM wbcrossgt
*    INTO TABLE @DATA(lt_wbcrossgt)
*    WHERE include IN @lt_includes.
*
*  IF sy-subrc <> 0.
*    MESSAGE 'No entries found in WBCROSSGT for given includes.' TYPE 'I'.
*  ENDIF.
*
*  SELECT * FROM cross
*    INTO TABLE @DATA(lt_cross)
*    WHERE include IN @lt_includes.
*
*  IF sy-subrc <> 0.
*    MESSAGE 'No entries found in CROSS for given includes.' TYPE 'I'.
*  ENDIF.

ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  EXPEND_FUGR
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      -->P_P_IT_TADIR  text
*      <--P_LR_FUGR_INCLUDE  text
*----------------------------------------------------------------------*
FORM expend_fugr  USING    pt_tadir TYPE  gyt_tadir
                  CHANGING p_lr_fugr_include TYPE gyr_include.

  DATA(lt_patterns) = VALUE string_table( FOR ls_fugr IN pt_tadir WHERE ( object = 'FUGR'
                                                                         AND obj_name NE ''
                                                                         AND object NP '/*' )
        ( |SAPL{ ls_fugr-obj_name }| )         " main program (exact match)
        ( |L{ ls_fugr-obj_name }TOP| )         " top include (exact match)
        ( |L{ ls_fugr-obj_name }D++| )         " declaration of local classes within the top include
        ( |L{ ls_fugr-obj_name }P++| )         " implementing the methods of local classes in the implementation section of the function group
        ( |L{ ls_fugr-obj_name }U++| )         " function modules (pattern)
        ( |L{ ls_fugr-obj_name }E++| )         " implementing event blocks in the implementation section of the function group.
        ( |L{ ls_fugr-obj_name }F++| )         " implementing subroutines in the implementation section of the function group.
        ( |L{ ls_fugr-obj_name }O++| )         " implementing PBO modules in the implementation section of the function group.
        ( |L{ ls_fugr-obj_name }I++| )         " implementing PAI modules in the implementation section of the function group.
      ).

*  p_lr_fugr_include = VALUE #( FOR ls_range IN lt_patterns ( sign = rs_c_range_sign-including
*                                                              option = rs_c_range_opt-equal
*                                                              low = ls_range ) ).

  APPEND LINES OF VALUE gyr_include( FOR ls_range IN lt_patterns
                                     ( sign = rs_c_range_sign-including
                                       option = rs_c_range_opt-equal
                                       low = ls_range ) ) TO p_lr_fugr_include.
ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  FIND_MATCH
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      -->P_LR_INCLUDE  text
*----------------------------------------------------------------------*
FORM find_match  USING    p_lr_include TYPE gyr_include.


  DATA: lt_cross     TYPE STANDARD TABLE OF cross,
        lt_wbcrossgt TYPE STANDARD TABLE OF wbcrossgt.


  PERFORM find_in_wbcrossgt USING p_lr_include CHANGING lt_wbcrossgt.

  PERFORM find_in_cross USING p_lr_include CHANGING lt_cross.


*  DELETE ADJACENT DUPLICATES FROM p_lr_include.

ENDFORM.

*&---------------------------------------------------------------------*
*&      Form  FIND_IN_WBCROSSGT
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      -->P_P_LR_INCLUDE  text
*----------------------------------------------------------------------*
FORM find_in_wbcrossgt  USING    p_p_lr_include TYPE gyr_include
                        CHANGING p_lt_wbcrossgt TYPE STANDARD TABLE.

  SELECT otype, name, include FROM wbcrossgt INTO TABLE @p_lt_wbcrossgt
                                    FOR ALL ENTRIES IN @p_p_lr_include WHERE include = @p_p_lr_include-low.

ENDFORM.
*&---------------------------------------------------------------------*
*&      Form  FIND_IN_CROSS
*&---------------------------------------------------------------------*
*       text
*----------------------------------------------------------------------*
*      -->P_P_LR_INCLUDE  text
*----------------------------------------------------------------------*
FORM find_in_cross  USING p_p_lr_include TYPE gyr_include
                    CHANGING p_lt_cross TYPE STANDARD TABLE.

  SELECT type, name, include FROM cross INTO TABLE @p_lt_cross FOR ALL ENTRIES IN @p_p_lr_include
                                          WHERE include = @p_p_lr_include-low.

*  LOOP AT p_lt_cross INTO DATA(ls_cross).
*    PERFORM convert_include USING ls_cross-name CHANGING ls_cross-type.
*    MODIFY p_lt_cross FROM ls_cross.
*  ENDLOOP.
ENDFORM.
