$region = $args[0]
Copy-Item -Path "e:\Web\LMSMobile\$region" -Destination "e:\Web\LMSMobile\$region-$((Get-Date).ToString('yyyy_MM_dd-hh_mm_ss'))" -Recurse