" filepath: c:\Users\boris\OneDrive\Documents\ABAP\ABAP_Project\expand_tadir.abap

REPORT expand_tadir.

* First section: Input details
SELECTION-SCREEN BEGIN OF BLOCK blk_input WITH FRAME TITLE text-001.
SELECT-OPTIONS: so_devc FOR tadir-devclass,
                so_type FOR tadir-object,
                so_name FOR obj_name.
SELECTION-SCREEN END OF BLOCK blk_input.

* Second section: Searching Limit
SELECTION-SCREEN BEGIN OF BLOCK blk_limit WITH FRAME TITLE text-002.
SELECT-OPTIONS: sl_type FOR tadir-object,
                sl_name FOR tadir-obj_name,
                sl_devc FOR tadir-devclass,
                sl_soft FOR tdevc-dlvunit.
SELECTION-SCREEN END OF BLOCK blk_limit.

* Text symbols for block titles
* text-001 = Input details
* text-002 = Searching Limit



TYPES: BEGIN OF ty_tadir,
         object   TYPE tadir-object,
         obj_name TYPE tadir-obj_name,
         devclass TYPE tadir-devclass,
         author   TYPE tadir-author,
       END OF ty_tadir.

TYPES ty_tadir_tab TYPE SORTED TABLE OF ty_tadir WITH UNIQUE KEY object obj_name.

DATA gt_tadir TYPE ty_tadir_tab.
DATA: lt_includes TYPE RANGE OF progname,
      lt_class_includes TYPE STANDARD TABLE OF progname,
      lv_classname TYPE tadir-obj_name.

FIELD-SYMBOLS: <ls_tadir> TYPE ty_tadir,
               <lv_include> TYPE progname.

START-OF-SELECTION.

  SELECT object
         obj_name
         devclass
         author
    FROM tadir
    INTO TABLE @gt_tadir
    WHERE devclass IN @so_devc
      AND object   IN @so_type
      AND obj_name IN @so_name.

  IF sy-subrc <> 0.
    MESSAGE 'No entries found in TADIR for given selection.' TYPE 'I'.
    EXIT.
  ENDIF.

  CLEAR lt_includes.

  LOOP AT gt_tadir ASSIGNING <ls_tadir>.
    CLEAR lt_class_includes.
    CALL METHOD cl_oo_classname_service=>get_all_class_includes
      EXPORTING
        classname = <ls_tadir>-obj_name
      IMPORTING
        includes  = lt_class_includes.

    IF sy-subrc <> 0.
      CONTINUE.
    ENDIF.

    LOOP AT lt_class_includes ASSIGNING <lv_include>.
      APPEND VALUE #( sign = 'I' option = 'EQ' low = <lv_include> ) TO lt_includes.
    ENDLOOP.
  ENDLOOP.

  * Remove duplicates from range table
  SORT lt_includes BY low.
  DELETE ADJACENT DUPLICATES FROM lt_includes COMPARING low.

  * Example: Read WBCROSSGT using the range table
  SELECT * FROM wbcrossgt
    INTO TABLE @DATA(lt_wbcrossgt)
    WHERE include IN @lt_includes.

  IF sy-subrc <> 0.
    MESSAGE 'No entries found in WBCROSSGT for given includes.' TYPE 'I'.
  ENDIF.

  SELECT * FROM cross
    INTO TABLE @DATA(lt_cross)
    WHERE include IN @lt_includes.

  IF sy-subrc <> 0.
    MESSAGE 'No entries found in CROSS for given includes.' TYPE 'I'.
  ENDIF.

