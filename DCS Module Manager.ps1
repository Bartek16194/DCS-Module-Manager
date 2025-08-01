Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Klucz rejestru dla konfiguracji
$RegistryPath = "HKCU:\Software\DCSModuleInstaller"

function Save-DCSPath {
    param($Path)
    if (-not (Test-Path $RegistryPath)) {
        New-Item -Path $RegistryPath -Force | Out-Null
    }
    Set-ItemProperty -Path $RegistryPath -Name "DCSPath" -Value $Path
}

function Load-DCSPath {
    try {
        if (Test-Path $RegistryPath) {
            $path = Get-ItemProperty -Path $RegistryPath -Name "DCSPath" -ErrorAction SilentlyContinue
            if ($path) {
                return $path.DCSPath
            }
        }
    }
    catch {
        return $null
    }
    return $null
}

function Get-InstalledModulesFromAutoupdate {
    param($DCSRoot)
    $cfgPath = Join-Path $DCSRoot "autoupdate.cfg"
    if (-Not (Test-Path $cfgPath)) {
        [System.Windows.Forms.MessageBox]::Show("autoupdate.cfg not found in selected folder.`nPlease select correct DCS root folder.", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        return $null
    }
    $json = Get-Content $cfgPath -Raw | ConvertFrom-Json
    return $json.modules
}

function Show-FolderBrowser {
    param($InitialPath)
    
    $folderBrowser = New-Object System.Windows.Forms.FolderBrowserDialog
    $folderBrowser.Description = "Select DCS root folder (where autoupdate.cfg is)"
    $folderBrowser.ShowNewFolderButton = $false
    
    if ($InitialPath -and (Test-Path $InitialPath)) {
        $folderBrowser.SelectedPath = $InitialPath
    }
    
    $result = $folderBrowser.ShowDialog()
    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        return $folderBrowser.SelectedPath
    } else {
        exit
    }
}

function BackupInputFiles {
    # Zapytaj o folder źródłowy (Input)
    $sourceDialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $sourceDialog.Description = "Select Input Config Folder"
    $sourceDialog.ShowNewFolderButton = $false
    
    # Domyślna ścieżka do Input
    $defaultInputPath = Join-Path $env:USERPROFILE "Saved Games\DCS.openbeta\Config\Input"
    if (Test-Path $defaultInputPath) {
        $sourceDialog.SelectedPath = $defaultInputPath
    }
    
    if ($sourceDialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
        [System.Windows.Forms.MessageBox]::Show("Source folder selection canceled.", "Backup Aborted", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        return
    }
    $sourcePath = $sourceDialog.SelectedPath
    
    # Zapytaj o folder docelowy
    $destDialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $destDialog.Description = "Select Backup Destination Folder"
    $destDialog.ShowNewFolderButton = $true
    
    # Domyślna ścieżka - Desktop
    $desktopPath = [Environment]::GetFolderPath("Desktop")
    $destDialog.SelectedPath = $desktopPath
    
    if ($destDialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
        [System.Windows.Forms.MessageBox]::Show("Destination folder selection canceled.", "Backup Aborted", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        return
    }
    $destBasePath = $destDialog.SelectedPath
    
    # Utwórz nazwę folderu z timestamp
    $timestamp = Get-Date -Format "yyyy-MM-dd - HH;mm;ss"
    $folderName = "backup input $timestamp"
    $backupFolder = Join-Path $destBasePath $folderName
    
    try {
        # Utwórz folder backup
        New-Item -Path $backupFolder -ItemType Directory -Force | Out-Null
        
        # Skopiuj wszystkie pliki rekursywnie
        $sourceFiles = Join-Path $sourcePath "*"
        Copy-Item -Path $sourceFiles -Destination $backupFolder -Recurse -Force
        
        [System.Windows.Forms.MessageBox]::Show("Backup completed successfully!`n`nBackup location:`n$backupFolder", "Success", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show("Backup failed:`n$($_.Exception.Message)", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
}

function Show-InstallationResult {
    param($DCSRoot, $ExpectedModules, $ActualModules, $Operation)
    
    $operationText = if ($Operation -eq "install") { "installation" } else { "uninstallation" }
    $expectedText = if ($Operation -eq "install") { "Expected to be installed:" } else { "Expected to be removed:" }
    
    if ($Operation -eq "install") {
        $missingModules = $ExpectedModules | Where-Object { $_ -notin $ActualModules }
        $success = $missingModules.Count -eq 0
    } else {
        $stillInstalledModules = $ExpectedModules | Where-Object { $_ -in $ActualModules }
        $success = $stillInstalledModules.Count -eq 0
        $missingModules = $stillInstalledModules
    }
    
    $resultForm = New-Object System.Windows.Forms.Form
    $resultForm.Text = "Installation Result"
    $resultForm.Size = New-Object System.Drawing.Size(600, 500)
    $resultForm.StartPosition = "CenterScreen"
    $resultForm.FormBorderStyle = 'FixedDialog'
    $resultForm.MaximizeBox = $false
    $resultForm.MinimizeBox = $false
    
    if ($success) {
        # Sukces
        $statusLabel = New-Object System.Windows.Forms.Label
        $statusLabel.Text = "SUCCESS: $operationText completed successfully!"
        $statusLabel.Location = New-Object System.Drawing.Point(10, 10)
        $statusLabel.Size = New-Object System.Drawing.Size(560, 30)
        $statusLabel.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 12, [System.Drawing.FontStyle]::Bold)
        $statusLabel.ForeColor = [System.Drawing.Color]::Green
        $resultForm.Controls.Add($statusLabel)
        
        $detailsLabel = New-Object System.Windows.Forms.Label
        $detailsLabel.Text = "All selected modules have been processed correctly."
        $detailsLabel.Location = New-Object System.Drawing.Point(10, 50)
        $detailsLabel.Size = New-Object System.Drawing.Size(560, 20)
        $resultForm.Controls.Add($detailsLabel)
        
        # OK button
        $okButton = New-Object System.Windows.Forms.Button
        $okButton.Text = "OK"
        $okButton.Size = New-Object System.Drawing.Size(80, 30)
        $okButton.Location = New-Object System.Drawing.Point(260, 420)
        $okButton.Add_Click({ $resultForm.Close() })
        $resultForm.Controls.Add($okButton)
        
    } else {
        # Błąd
        $statusLabel = New-Object System.Windows.Forms.Label
        $statusLabel.Text = "ERROR: $operationText failed!"
        $statusLabel.Location = New-Object System.Drawing.Point(10, 10)
        $statusLabel.Size = New-Object System.Drawing.Size(560, 30)
        $statusLabel.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 12, [System.Drawing.FontStyle]::Bold)
        $statusLabel.ForeColor = [System.Drawing.Color]::Red
        $resultForm.Controls.Add($statusLabel)
        
        $expectedLabel = New-Object System.Windows.Forms.Label
        $expectedLabel.Text = $expectedText
        $expectedLabel.Location = New-Object System.Drawing.Point(10, 50)
        $expectedLabel.Size = New-Object System.Drawing.Size(560, 20)
        $expectedLabel.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 9, [System.Drawing.FontStyle]::Bold)
        $resultForm.Controls.Add($expectedLabel)
        
        # Lista modułów które nie zostały przetworzone
        $modulesList = New-Object System.Windows.Forms.ListBox
        $modulesList.Location = New-Object System.Drawing.Point(10, 75)
        $modulesList.Size = New-Object System.Drawing.Size(560, 100)
        foreach ($module in $ExpectedModules) {
            if ($module -in $missingModules) {
                $modulesList.Items.Add("FAILED: $module")
            } else {
                $modulesList.Items.Add("SUCCESS: $module")
            }
        }
        $resultForm.Controls.Add($modulesList)
        
        # Panel z przyciskami
        $buttonPanel = New-Object System.Windows.Forms.Panel
        $buttonPanel.Height = 60
        $buttonPanel.Dock = "Bottom"
        $resultForm.Controls.Add($buttonPanel)
        
        # Open Logs button
        $openLogsButton = New-Object System.Windows.Forms.Button
        $openLogsButton.Text = "Open Logs"
        $openLogsButton.Size = New-Object System.Drawing.Size(100, 30)
        $openLogsButton.Location = New-Object System.Drawing.Point(150, 15)
        $openLogsButton.Add_Click({
            $logPath = Join-Path $DCSRoot "autoupdate_log.txt"
            if (Test-Path $logPath) {
                Start-Process notepad.exe -ArgumentList $logPath
            } else {
                [System.Windows.Forms.MessageBox]::Show("Log file not found at: $logPath", "Log Not Found", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
            }
        })
        $buttonPanel.Controls.Add($openLogsButton)
        
        # Open DCS Folder button
        $openFolderButton = New-Object System.Windows.Forms.Button
        $openFolderButton.Text = "Open DCS Folder"
        $openFolderButton.Size = New-Object System.Drawing.Size(120, 30)
        $openFolderButton.Location = New-Object System.Drawing.Point(270, 15)
        $openFolderButton.Add_Click({
            Start-Process explorer.exe -ArgumentList $DCSRoot
        })
        $buttonPanel.Controls.Add($openFolderButton)
        
        # OK button
        $okButton = New-Object System.Windows.Forms.Button
        $okButton.Text = "OK"
        $okButton.Size = New-Object System.Drawing.Size(80, 30)
        $okButton.Location = New-Object System.Drawing.Point(410, 15)
        $okButton.Add_Click({ $resultForm.Close() })
        $buttonPanel.Controls.Add($okButton)
    }
    
    $resultForm.ShowDialog()
}

function Show-CommandConfirmation {
    param($Command, $SelectedModules, $SelectedKeys, $Operation, $DCSRoot)
    
    $operationText = if ($Operation -eq "install") { "Installation" } else { "Uninstallation" }
    $actionText = if ($Operation -eq "install") { "installation" } else { "removal" }
    
    $confirmForm = New-Object System.Windows.Forms.Form
    $confirmForm.Text = "Confirm $operationText"
    $confirmForm.Size = New-Object System.Drawing.Size(600, 500)
    $confirmForm.StartPosition = "CenterScreen"
    $confirmForm.FormBorderStyle = 'FixedDialog'
    $confirmForm.MaximizeBox = $false
    $confirmForm.MinimizeBox = $false
    
    # Label z informacją
    $infoLabel = New-Object System.Windows.Forms.Label
    $infoLabel.Text = "Selected modules for $actionText"
    $infoLabel.Location = New-Object System.Drawing.Point(10, 10)
    $infoLabel.Size = New-Object System.Drawing.Size(560, 20)
    $infoLabel.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 9, [System.Drawing.FontStyle]::Bold)
    $confirmForm.Controls.Add($infoLabel)
    
    # Lista wybranych modułów
    $modulesList = New-Object System.Windows.Forms.ListBox
    $modulesList.Location = New-Object System.Drawing.Point(10, 35)
    $modulesList.Size = New-Object System.Drawing.Size(560, 150)
    foreach ($module in $SelectedModules) {
        $modulesList.Items.Add($module)
    }
    $confirmForm.Controls.Add($modulesList)
    
    # Label dla komendy
    $commandLabel = New-Object System.Windows.Forms.Label
    $commandLabel.Text = "Command that will be executed:"
    $commandLabel.Location = New-Object System.Drawing.Point(10, 200)
    $commandLabel.Size = New-Object System.Drawing.Size(560, 20)
    $commandLabel.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 9, [System.Drawing.FontStyle]::Bold)
    $confirmForm.Controls.Add($commandLabel)
    
    # TextBox z komendą
    $commandTextBox = New-Object System.Windows.Forms.TextBox
    $commandTextBox.Location = New-Object System.Drawing.Point(10, 225)
    $commandTextBox.Size = New-Object System.Drawing.Size(560, 100)
    $commandTextBox.Multiline = $true
    $commandTextBox.ScrollBars = "Vertical"
    $commandTextBox.ReadOnly = $true
    $commandTextBox.Text = $Command
    $commandTextBox.Font = New-Object System.Drawing.Font("Consolas", 8)
    $confirmForm.Controls.Add($commandTextBox)
    
    # Panel z przyciskami
    $buttonPanel = New-Object System.Windows.Forms.Panel
    $buttonPanel.Height = 60
    $buttonPanel.Dock = "Bottom"
    $confirmForm.Controls.Add($buttonPanel)
    
    # Przycisk Copy to Clipboard
    $copyButton = New-Object System.Windows.Forms.Button
    $copyButton.Text = "Copy to Clipboard"
    $copyButton.Size = New-Object System.Drawing.Size(120, 30)
    $copyButton.Location = New-Object System.Drawing.Point(50, 15)
    $buttonPanel.Controls.Add($copyButton)
    
    # Przycisk Execute
    $executeButton = New-Object System.Windows.Forms.Button
    $executeButton.Text = "Execute Now"
    $executeButton.Size = New-Object System.Drawing.Size(100, 30)
    $executeButton.Location = New-Object System.Drawing.Point(200, 15)
    $executeButton.BackColor = [System.Drawing.Color]::LightGreen
    $buttonPanel.Controls.Add($executeButton)
    
    # Przycisk Cancel
    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Text = "Cancel"
    $cancelButton.Size = New-Object System.Drawing.Size(80, 30)
    $cancelButton.Location = New-Object System.Drawing.Point(320, 15)
    $buttonPanel.Controls.Add($cancelButton)
    
    # Przycisk Back
    $backButton = New-Object System.Windows.Forms.Button
    $backButton.Text = "Back"
    $backButton.Size = New-Object System.Drawing.Size(80, 30)
    $backButton.Location = New-Object System.Drawing.Point(420, 15)
    $buttonPanel.Controls.Add($backButton)
    
    # Event handlers
    $copyButton.Add_Click({
        [System.Windows.Forms.Clipboard]::SetText($Command)
        [System.Windows.Forms.MessageBox]::Show("Command copied to clipboard!", "Copied", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    })
    
    $executeButton.Add_Click({
        $result = [System.Windows.Forms.MessageBox]::Show("Are you sure you want to execute the $actionText command?`n`nThis will start the $actionText process for the selected modules.", "Confirm Execution", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
        if ($result -eq [System.Windows.Forms.DialogResult]::Yes) {
            try {
                # Użyj przekazanych kluczy modułów
                $moduleKeys = $SelectedKeys
                
                Write-Host "Module keys for verification: $($moduleKeys -join ', ')"
                
                # Wykonaj komendę
                $process = Start-Process -FilePath "cmd.exe" -ArgumentList "/c", $Command -Wait -PassThru
                
                # Poczekaj chwilę na aktualizację pliku
                Start-Sleep -Seconds 2
                
                # Sprawdź wynik
                $newInstalledModules = Get-InstalledModulesFromAutoupdate -DCSRoot $DCSRoot
                if ($newInstalledModules -ne $null) {
                    Show-InstallationResult -DCSRoot $DCSRoot -ExpectedModules $moduleKeys -ActualModules $newInstalledModules -Operation $Operation
                }
                
                $confirmForm.Close()
            }
            catch {
                [System.Windows.Forms.MessageBox]::Show("Error executing command: $($_.Exception.Message)", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
            }
        }
    })
    
    $cancelButton.Add_Click({
        $confirmForm.Close()
    })
    
    $backButton.Add_Click({
        $confirmForm.DialogResult = [System.Windows.Forms.DialogResult]::Retry
        $confirmForm.Close()
    })
    
    return $confirmForm.ShowDialog()
}

# --- Define all available modules with categories, developers and display names ---
$AllModules = @(
    # Terrains
    @{Key="CAUCASUS_terrain";        Name="Caucasus";               Category="Terrains"; Developer="Eagle Dynamics"}
    @{Key="NEVADA_terrain";          Name="Nevada Test and Training Range"; Category="Terrains"; Developer="Eagle Dynamics"}
    @{Key="PERSIANGULF_terrain";     Name="Persian Gulf";           Category="Terrains"; Developer="Eagle Dynamics"}
    @{Key="THECHANNEL_terrain";      Name="The Channel";            Category="Terrains"; Developer="Eagle Dynamics"}
    @{Key="MARIANAISLANDS_terrain";  Name="Mariana Islands";        Category="Terrains"; Developer="Eagle Dynamics"}
    @{Key="MARIANAISLANDSWWII_terrain"; Name="Mariana Islands (Historic)"; Category="Terrains"; Developer="Eagle Dynamics"}
    @{Key="AFGHANISTAN_terrain";     Name="Afghanistan";            Category="Terrains"; Developer="Eagle Dynamics"}
    @{Key="IRAQ_terrain";            Name="Iraq";                   Category="Terrains"; Developer="Eagle Dynamics"}
    @{Key="KOLA_terrain";            Name="Kola Peninsula";         Category="Terrains"; Developer="OrbX"}
    @{Key="NORMANDY_terrain";        Name="Normandy 2.0";           Category="Terrains"; Developer="Ugra Media"}
    @{Key="SYRIA_terrain";           Name="Syria";                  Category="Terrains"; Developer="Ugra Media"}
    @{Key="GERMANYCW_terrain";       Name="Germany Cold War";       Category="Terrains"; Developer="Ugra Media"}
    @{Key="FALKLANDS_terrain";       Name="South Atlantic";         Category="Terrains"; Developer="Razbam"}
    @{Key="SINAIMAP_terrain";        Name="Sinai";                  Category="Terrains"; Developer="Onretech"}

    # Technology / Asset Packs
    @{Key="CA";                      Name="Combined Arms";          Category="Technology"; Developer="Eagle Dynamics"}
    @{Key="WWII-ARMOUR";             Name="WWII Assets Pack";       Category="Technology"; Developer="Eagle Dynamics"}
    @{Key="NS430";                   Name="NS430 Core";             Category="Technology"; Developer="Eagle Dynamics"}
    @{Key="SUPERCARRIER";            Name="Supercarrier";           Category="Technology"; Developer="Eagle Dynamics"}
    @{Key="NS430_MI-8MT2";           Name="NS430 for Mi-8MTV2";     Category="Technology"; Developer="Eagle Dynamics"}
    @{Key="NS430_L-39";              Name="NS430 for L-39C";        Category="Technology"; Developer="Eagle Dynamics"}
    @{Key="NS430_C-101CC";           Name="NS430 for C-101CC";      Category="Technology"; Developer="Aerges"}
    @{Key="NS430_C-101EB";           Name="NS430 for C-101EB";      Category="Technology"; Developer="Aerges"}
    @{Key="NS430_SA342";             Name="NS430 for SA342";        Category="Technology"; Developer="Polychop"}
    @{Key="NS430_CHRISTEN_EAGLE_II"; Name="NS430 for Christen Eagle II"; Category="Technology"; Developer="Magnitude 3"}

    # Aircraft Modules - Eagle Dynamics
    @{Key="A-10A";                   Name="A-10A Thunderbolt II";   Category="Aircraft"; Developer="Eagle Dynamics"}
    @{Key="A-10C_2";                 Name="A-10C II Thunderbolt";   Category="Aircraft"; Developer="Eagle Dynamics"}
    @{Key="AH-64D";                  Name="AH-64D Apache";          Category="Aircraft"; Developer="Eagle Dynamics"}
    @{Key="BF-109K4";                Name="Bf-109K4 Kurfurst";      Category="Aircraft"; Developer="Eagle Dynamics"}
    @{Key="CH-47F";                  Name="CH-47F Chinook";         Category="Aircraft"; Developer="Eagle Dynamics"}
    @{Key="F-15C";                   Name="F-15C Eagle";            Category="Aircraft"; Developer="Eagle Dynamics"}
    @{Key="F-16C";                   Name="F-16C Viper";            Category="Aircraft"; Developer="Eagle Dynamics"}
    @{Key="FA-18C";                  Name="F/A-18C Hornet";         Category="Aircraft"; Developer="Eagle Dynamics"}
    @{Key="F-5E";                    Name="F-5E Tiger II (Legacy)";          Category="Aircraft"; Developer="Eagle Dynamics"}
    @{Key="F-5E_2024";               Name="F-5E Tiger II Remaster (2024)";   Category="Aircraft"; Developer="Eagle Dynamics"}
    @{Key="FC3";               Name="Flaming Cliffs 3";   Category="Aircraft"; Developer="Eagle Dynamics"}
    @{Key="FW-190A8";                Name="Fw-190A8 Anton";         Category="Aircraft"; Developer="Eagle Dynamics"}
    @{Key="FW-190D9";                Name="Fw-190D9 Dora";          Category="Aircraft"; Developer="Eagle Dynamics"}
    @{Key="KA-50";                   Name="Ka-50 Black Shark II";   Category="Aircraft"; Developer="Eagle Dynamics"}
    @{Key="KA-50_3";                 Name="Ka-50 Black Shark III";  Category="Aircraft"; Developer="Eagle Dynamics"}
    @{Key="L-39C";                   Name="L-39C Albatros";         Category="Aircraft"; Developer="Eagle Dynamics"}
    @{Key="MI-8MTV2";                Name="Mi-8MTV2 Hip";           Category="Aircraft"; Developer="Eagle Dynamics"}
    @{Key="MI-24P";                  Name="Mi-24P Hind";            Category="Aircraft"; Developer="Eagle Dynamics"}
    @{Key="MIG-29";                  Name="MiG-29 Fulcrum";         Category="Aircraft"; Developer="Eagle Dynamics"}
    @{Key="MOSQUITO-FBMKVI";         Name="Mosquito FB VI";         Category="Aircraft"; Developer="Eagle Dynamics"}
    @{Key="P-51D";                   Name="P-51D Mustang";          Category="Aircraft"; Developer="Eagle Dynamics"}
    @{Key="P47D30";                  Name="P-47D Thunderbolt";      Category="Aircraft"; Developer="Eagle Dynamics"}
    @{Key="SPITFIRE-MKIX";           Name="Spitfire LF Mk IX";      Category="Aircraft"; Developer="Eagle Dynamics"}
    @{Key="SU-25A";                  Name="Su-25A Frogfoot";        Category="Aircraft"; Developer="Eagle Dynamics"}
    @{Key="SU-27";                   Name="Su-27 Flanker";          Category="Aircraft"; Developer="Eagle Dynamics"}
    @{Key="SU-33";                   Name="Su-33 Flanker D";        Category="Aircraft"; Developer="Eagle Dynamics"}
    @{Key="UH-1H";                   Name="UH-1H Huey";             Category="Aircraft"; Developer="Eagle Dynamics"}
    @{Key="YAK-52";                  Name="Yak-52";                 Category="Aircraft"; Developer="Eagle Dynamics"}
    @{Key="F-86F";                   Name="F-86F Sabre";            Category="Aircraft"; Developer="Eagle Dynamics"}
    @{Key="MIG-15BIS";               Name="MiG-15bis Fagot";        Category="Aircraft"; Developer="Eagle Dynamics"}

#FC2024 / 3
    @{Key="F-5E_FC";                 Name="F-5E Tiger II (Flaming Cliffs 2024)";         Category="Aircraft"; Developer="Eagle Dynamics"}
    @{Key="F-86F_FC";             Name="F-86F Sabre (Flaming Cliffs 2024)";         Category="Aircraft"; Developer="Eagle Dynamics"}
    @{Key="MIG-15BIS_FC";            Name="MIG-15Bis Fagot (Flaming Cliffs 2024)";         Category="Aircraft"; Developer="Eagle Dynamics"}

    # Aircraft Modules - Third Party
    @{Key="AERGES_MIRAGE-F1";        Name="Mirage F1";              Category="Aircraft"; Developer="Aerges"}
    @{Key="AVIODEV_C-101";           Name="C-101 Aviojet";          Category="Aircraft"; Developer="AvioDev"}
    @{Key="AJS37";                   Name="AJS-37 Viggen";          Category="Aircraft"; Developer="Heatblur"}
    @{Key="DEKA_JF-17";              Name="JF-17 Thunder";          Category="Aircraft"; Developer="Deka Ironwork"}
    @{Key="HEATBLUR_F-14";           Name="F-14 Tomcat";            Category="Aircraft"; Developer="Heatblur"}
    @{Key="HEATBLUR_F-4E";           Name="F-4E Phantom II";        Category="Aircraft"; Developer="Heatblur"}
    @{Key="INDIAFOXTECHO_MB-339";    Name="MB-339";                 Category="Aircraft"; Developer="IndiaFoxtEcho"}
    @{Key="MAGNITUDE3_CHRISTEN_EAGLE-II"; Name="Christen Eagle II"; Category="Aircraft"; Developer="Magnitude 3"}
    @{Key="MAGNITUDE3_F4U-1D";       Name="F4U-1D Corsair";         Category="Aircraft"; Developer="Magnitude 3"}
    @{Key="MIG-21BIS";               Name="MiG-21bis Fishbed";      Category="Aircraft"; Developer="Magnitude 3"}
    @{Key="OCTOPUSG_I-16";           Name="I-16 Ishachok";          Category="Aircraft"; Developer="OctopusG"}
    @{Key="POLYCHOPSIM_SA342";       Name="SA342 Gazelle";          Category="Aircraft"; Developer="Polychop"}
    @{Key="POLYCHOPSIM_OH58D";        Name="OH-58D Kiowa Warrior";Category="Aircraft"; Developer="Polychop"}
    @{Key="RAZBAM_AV8BNA";           Name="AV-8B N.A. Harrier";     Category="Aircraft"; Developer="Razbam"}
    @{Key="RAZBAM_F-15E";            Name="F-15E Strike Eagle";     Category="Aircraft"; Developer="Razbam"}
    @{Key="RAZBAM_M-2000C";          Name="Mirage 2000C";           Category="Aircraft"; Developer="Razbam"}
    @{Key="RAZBAM_MIG19P";           Name="MiG-19P Farmer";         Category="Aircraft"; Developer="Razbam"}
)

# Organize modules by category and developer
$Categories = @{}
foreach ($module in $AllModules) {
    if (-not $Categories.ContainsKey($module.Category)) {
        $Categories[$module.Category] = @{}
    }
    if (-not $Categories[$module.Category].ContainsKey($module.Developer)) {
        $Categories[$module.Category][$module.Developer] = @()
    }
    $Categories[$module.Category][$module.Developer] += $module
}

# Sort everything alphabetically
$SortedCategories = $Categories.GetEnumerator() | Sort-Object Name
foreach ($category in $SortedCategories) {
    $SortedDevelopers = $category.Value.GetEnumerator() | Sort-Object Name
    $category.Value = [ordered]@{}
    foreach ($dev in $SortedDevelopers) {
        $category.Value[$dev.Name] = $dev.Value | Sort-Object Name
    }
}

function Create-ModuleTab {
    param($TabControl, $TabName, $Operation, $InstalledModules, $DCSRoot)
    
    # Create tab
    $tab = New-Object System.Windows.Forms.TabPage
    $tab.Text = $TabName
    $TabControl.Controls.Add($tab)

    # Container panel dla całej zawartości
    $containerPanel = New-Object System.Windows.Forms.Panel
    $containerPanel.Dock = "Fill"
    $tab.Controls.Add($containerPanel)

    # Nested tab control for categories
    $categoryTabControl = New-Object System.Windows.Forms.TabControl
    $categoryTabControl.Dock = "Fill"
    $containerPanel.Controls.Add($categoryTabControl)

    # Keep checkboxes to collect selection
    $checkboxes = New-Object System.Collections.ArrayList

    foreach ($category in $SortedCategories) {
        # Create category tab
        $categoryTab = New-Object System.Windows.Forms.TabPage
        $categoryTab.Text = $category.Name
        $categoryTabControl.Controls.Add($categoryTab)

        # Scrollable panel inside category tab
        $panel = New-Object System.Windows.Forms.Panel
        $panel.Dock = "Fill"
        $panel.AutoScroll = $true
        $categoryTab.Controls.Add($panel)

        $y = 10
        # Sort developers alphabetically
        $sortedDeveloperNames = $category.Value.Keys | Sort-Object
        foreach ($developerName in $sortedDeveloperNames) {
            $developerModules = $category.Value[$developerName]
            
            # Add developer label
            $label = New-Object System.Windows.Forms.Label
            $label.Text = $developerName
            $label.AutoSize = $true
            $label.Font = New-Object System.Drawing.Font("Microsoft Sans Serif", 8, [System.Drawing.FontStyle]::Bold)
            $label.Location = New-Object System.Drawing.Point(10, $y)
            $panel.Controls.Add($label)
            $y += 20

            foreach ($mod in $developerModules) {
                $cb = New-Object System.Windows.Forms.CheckBox
                $cb.Text = $mod.Name
                $cb.Tag = $mod.Key
                $cb.AutoSize = $true
                $cb.Location = New-Object System.Drawing.Point(20, $y)

                if ($Operation -eq "install") {
                    # Install tab - disable already installed modules
                    if ($InstalledModules -contains $mod.Key) {
                        $cb.Checked = $true
                        $cb.Enabled = $false
                        $cb.ForeColor = [System.Drawing.Color]::Gray
                    }
                } else {
                    # Uninstall tab - enable only installed modules
                    if ($InstalledModules -contains $mod.Key) {
                        $cb.Enabled = $true
                    } else {
                        $cb.Enabled = $false
                        $cb.ForeColor = [System.Drawing.Color]::Gray
                    }
                }

                $panel.Controls.Add($cb)
                [void]$checkboxes.Add($cb)
                $y += 25
            }
            $y += 5
        }
    }

    # Panel na dole z przyciskami
    $bottomPanel = New-Object System.Windows.Forms.Panel
    $bottomPanel.Height = 60
    $bottomPanel.Dock = "Bottom"
    $containerPanel.Controls.Add($bottomPanel)

    # Next button
    $nextButton = New-Object System.Windows.Forms.Button
    $nextButton.Text = "Next >"
    $nextButton.Width = 100
    $nextButton.Height = 30
    if ($Operation -eq "install") {
        $nextButton.BackColor = [System.Drawing.Color]::LightBlue
    } else {
        $nextButton.BackColor = [System.Drawing.Color]::LightCoral
    }
    $buttonX = [math]::Round((700 - $nextButton.Width) / 2)
    $nextButton.Location = New-Object System.Drawing.Point($buttonX, 15)
    $bottomPanel.Controls.Add($nextButton)

    # Przechowaj dane w Tag przycisku
    $nextButton.Tag = @{
        Operation = $Operation
        DCSRoot = $DCSRoot
        InstalledModules = $InstalledModules
        Checkboxes = $checkboxes
    }

    # Event handler używający danych z Tag
    $nextButton.Add_Click({
        $data = $this.Tag
        $localOperation = $data.Operation
        $localDCSRoot = $data.DCSRoot
        $localInstalledModules = $data.InstalledModules
        $localCheckboxes = $data.Checkboxes
        
        # Logika sprawdzania
        $selectedCheckboxes = @()
        
        if ($localOperation -eq "install") {
            # Install: wybierz zaznaczone checkboxy które są włączone (nie zainstalowane)
            $selectedCheckboxes = @($localCheckboxes | Where-Object { $_.Checked -and $_.Enabled })
        } else {
            # Uninstall: wybierz zaznaczone checkboxy które są włączone
            $selectedCheckboxes = @($localCheckboxes | Where-Object { $_.Checked -and $_.Enabled })
        }
        
        if ($selectedCheckboxes.Count -eq 0) {
            $actionText = if ($localOperation -eq "install") { "installation" } else { "uninstallation" }
            $message = "No modules selected for $actionText."
            [System.Windows.Forms.MessageBox]::Show($message, "Info", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
            return
        }
        
        # Pobierz klucze i nazwy
        $selectedKeys = $selectedCheckboxes | ForEach-Object { $_.Tag }
        $selectedModuleNames = $selectedCheckboxes | ForEach-Object { $_.Text }
        
        $exePath = Join-Path $localDCSRoot "Bin\DCS_updater.exe"
        $command = if ($localOperation -eq "install") {
            '"' + $exePath + '" install ' + ($selectedKeys -join ' ')
        } else {
            '"' + $exePath + '" uninstall ' + ($selectedKeys -join ' ')
        }
        
        $result = Show-CommandConfirmation -Command $command -SelectedModules $selectedModuleNames -SelectedKeys $selectedKeys -Operation $localOperation -DCSRoot $localDCSRoot
        if ($result -eq [System.Windows.Forms.DialogResult]::Retry) {
            # Użytkownik kliknął Back
        } else {
            # Znajdź główne okno i je zamknij
            $form = $this.FindForm()
            if ($form) {
                $form.DialogResult = [System.Windows.Forms.DialogResult]::OK
                $form.Close()
            }
        }
    })
}

function Create-OtherTab {
    param($TabControl)
    
    # Utwórz zakładkę Other
    $otherTab = New-Object System.Windows.Forms.TabPage
    $otherTab.Text = "Other"
    $TabControl.Controls.Add($otherTab)
    
    # Panel główny
    $mainPanel = New-Object System.Windows.Forms.Panel
    $mainPanel.Dock = "Fill"
    $otherTab.Controls.Add($mainPanel)
    
    # Przycisk Input Backup
    $backupButton = New-Object System.Windows.Forms.Button
    $backupButton.Text = "Input Backup"
    $backupButton.Size = New-Object System.Drawing.Size(150, 40)
    $backupButton.Location = New-Object System.Drawing.Point(20, 20)
    $backupButton.BackColor = [System.Drawing.Color]::LightGreen
    $mainPanel.Controls.Add($backupButton)
    
    # Event handler dla przycisku
    $backupButton.Add_Click({
        BackupInputFiles
    })
    
    # Label z opisem
    $descLabel = New-Object System.Windows.Forms.Label
    $descLabel.Text = "Backup your DCS Input configuration files to a safe location."
    $descLabel.Location = New-Object System.Drawing.Point(20, 70)
    $descLabel.Size = New-Object System.Drawing.Size(400, 20)
    $descLabel.ForeColor = [System.Drawing.Color]::Gray
    $mainPanel.Controls.Add($descLabel)
}

# --- Main script ---
do {
    # Próbuj załadować zapamiętaną ścieżkę
    $SavedPath = Load-DCSPath

    # Zapytaj o folder DCS
    $DCSRoot = Show-FolderBrowser -InitialPath $SavedPath

    # Sprawdź czy ścieżka jest poprawna i zapisz ją
    $InstalledModules = Get-InstalledModulesFromAutoupdate -DCSRoot $DCSRoot
    if ($InstalledModules -eq $null) {
        exit
    }

    # Zapisz poprawną ścieżkę
    Save-DCSPath -Path $DCSRoot

    # Create form
    $form = New-Object System.Windows.Forms.Form
    $form.Text = "DCS Module Manager - $DCSRoot"
    $form.Size = New-Object System.Drawing.Size(700, 750)
    $form.StartPosition = "CenterScreen"
    $form.FormBorderStyle = 'FixedDialog'
    $form.MaximizeBox = $false
    $form.MinimizeBox = $false

    # Main tab control
    $mainTabControl = New-Object System.Windows.Forms.TabControl
    $mainTabControl.Dock = "Fill"
    $form.Controls.Add($mainTabControl)

    # Create Install and Uninstall tabs
    Create-ModuleTab -TabControl $mainTabControl -TabName "Install" -Operation "install" -InstalledModules $InstalledModules -DCSRoot $DCSRoot
    Create-ModuleTab -TabControl $mainTabControl -TabName "Uninstall" -Operation "uninstall" -InstalledModules $InstalledModules -DCSRoot $DCSRoot
    
    # Create Other tab
    Create-OtherTab -TabControl $mainTabControl

    # Panel na dole głównego okna
    $bottomPanel = New-Object System.Windows.Forms.Panel
    $bottomPanel.Height = 60
    $bottomPanel.Dock = "Bottom"
    $form.Controls.Add($bottomPanel)

    # Przycisk Change Path
    $changePathButton = New-Object System.Windows.Forms.Button
    $changePathButton.Text = "Change DCS Path"
    $changePathButton.Width = 120
    $changePathButton.Height = 30
    $changePathButton.Location = New-Object System.Drawing.Point(50, 15)
    $bottomPanel.Controls.Add($changePathButton)

    # Cancel button
    $cancelButton = New-Object System.Windows.Forms.Button
    $cancelButton.Text = "Exit"
    $cancelButton.Width = 80
    $cancelButton.Height = 30
    $cancelButton.Location = New-Object System.Drawing.Point(520, 15)
    $bottomPanel.Controls.Add($cancelButton)

    # Stopka
    $footerPanel = New-Object System.Windows.Forms.Panel
    $footerPanel.Height = 25
    $footerPanel.Dock = "Bottom"
    $form.Controls.Add($footerPanel)

    $nickLabel = New-Object System.Windows.Forms.Label
    $nickLabel.Text = "by Bartek16194"
    $nickLabel.AutoSize = $true
    $nickLabel.ForeColor = [System.Drawing.Color]::Gray
    $nickLabel.Location = New-Object System.Drawing.Point(10,3)
    $nickLabel.Font = New-Object System.Drawing.Font("Microsoft Sans Serif",8)
    $footerPanel.Controls.Add($nickLabel)

    $gitLink = New-Object System.Windows.Forms.LinkLabel
    $gitLink.Text = "GitHub"
    $gitLink.AutoSize = $true
    $gitLink.Location = New-Object System.Drawing.Point(600,3)
    $gitLink.Links.Add(0,$gitLink.Text.Length,"https://github.com/Bartek16194")
    $gitLink.LinkBehavior = [System.Windows.Forms.LinkBehavior]::AlwaysUnderline
    $gitLink.Add_LinkClicked({ Start-Process $_.Link.LinkData })
    $footerPanel.Controls.Add($gitLink)

    # Event handlers
    $changePathButton.Add_Click({
        $form.DialogResult = [System.Windows.Forms.DialogResult]::Ignore
        $form.Close()
    })

    $cancelButton.Add_Click({
        $form.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
        $form.Close()
    })

    $result = $form.ShowDialog()
    
} while ($result -eq [System.Windows.Forms.DialogResult]::Ignore) # Restart jeśli zmieniono ścieżkę
