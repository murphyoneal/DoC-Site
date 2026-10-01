#!/bin/bash
# EXIT CODE (ruling 887): each load's status is now accumulated; any failure fails the run.
cd ~
fail=0
S="https://ca.dep.state.fl.us/arcgis/rest/services/OpenData/DWM_STCM/MapServer"
echo "===== TANKS (layer 1) ====="
python3 arcgis_point_load.py "$S/1" fdep_stcm_tanks storage_tanks "FDEP STCM Registered Tanks (UST/AST inventory); feeds underground_storage_tanks_500m; daily refresh; site-level" 2>&1
rc=$?; if [ $rc -ne 0 ]; then echo "  FAILED rc=$rc"; fail=1; fi
echo "===== PCTS DISCHARGES (layer 2) ====="
python3 arcgis_point_load.py "$S/2" fdep_pcts_discharges petroleum_contamination "FDEP PCTS petroleum discharges from STCM; primary petroleum contamination source; daily; site-level" 2>&1
rc=$?; if [ $rc -ne 0 ]; then echo "  FAILED rc=$rc"; fail=1; fi
echo "===== DRYCLEANING (layer 4) ====="
python3 arcgis_point_load.py "$S/4" fdep_drycleaning_sites drycleaning_solvent "FDEP Drycleaning Solvent Program Cleanup Sites; SEPARATE DB from CLM (answers item5: not folded into OTHCU); PCE/TCE vapor-intrusion; daily; site-level" 2>&1
rc=$?; if [ $rc -ne 0 ]; then echo "  FAILED rc=$rc"; fail=1; fi
echo "===== STCM CONTAMINATION (layer 5) ====="
python3 arcgis_point_load.py "$S/5" fdep_stcm_contamination storage_tank_contamination "FDEP Storage Tank Contamination Monitoring facilities; daily; site-level" 2>&1
rc=$?; if [ $rc -ne 0 ]; then echo "  FAILED rc=$rc"; fail=1; fi
echo "===== ALL STCM DONE (fail=$fail) ====="
exit $fail
