#set proj "f32c_ulx2s"
# set proj "project"
foreach proj $::argv {
  prj_project open "$proj.ldf"
  prj_run Synthesis -impl $proj
  prj_run Map -impl $proj
  prj_run PAR -impl $proj
  prj_run Export -impl $proj -task Bitgen
}
