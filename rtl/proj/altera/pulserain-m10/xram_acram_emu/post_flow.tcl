post_message "Generating images for onchip flash..."
exec quartus_cpf -c dual_image.cof
file copy -force f32c_dual_boot.pof full_image.pof
file copy -force f32c_dual_boot_cfm1_auto.rpd cfm.bin
file copy -force f32c_dual_boot_ufm_auto.rpd ufm.bin
post_message " -- Flash images: full_image.pof cfm.bin ufm.bin"
