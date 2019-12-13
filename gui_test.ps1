Function switch-smtp($rmv,$add,$smtp) {
    # run with user that has permissions to set distribution group or implement that it imports exchange modules
    write-host "Set-DistributionGroup -identity $($rmv) -emailaddresses @{Remove=$($smtp)}"
    write-host "Set-DistributionGroup -identity $($add) -emailaddresses @{Add=$($smtp)}"
    #Set-DistributionGroup -identity $rmv   -emailaddresses @{Remove=$smtp}    -whatif
    #Set-DistributionGroup -identity $add   -emailaddresses @{Add=$smtp}       -whatif
}

function start-form{

    $lbl_X = 25
    $tb_X = 175
    Add-Type -AssemblyName System.Windows.Forms
    
    [System.Windows.Forms.Application]::EnableVisualStyles()
    
    $Form                            = New-Object system.Windows.Forms.Form
    $Form.ClientSize                 = '400,400'
    $Form.text                       = "Form"
    $Form.TopMost                    = $false
    ## Labels
    $lbl_rmv_frm                     = New-Object system.Windows.Forms.Label
    $lbl_rmv_frm.text                = "Remove from group"
    $lbl_rmv_frm.AutoSize            = $true
    $lbl_rmv_frm.width               = 25
    $lbl_rmv_frm.height              = 10
    $lbl_rmv_frm.location            = New-Object System.Drawing.Point($lbl_X,30)
    $lbl_rmv_frm.Font                = 'Microsoft Sans Serif,10'

    $lbl_add_to                      = New-Object system.Windows.Forms.Label
    $lbl_add_to.text                 = "Add to group"
    $lbl_add_to.AutoSize             = $true
    $lbl_add_to.width                = 25
    $lbl_add_to.height               = 10
    $lbl_add_to.location             = New-Object System.Drawing.Point($lbl_X,60)
    $lbl_add_to.Font                 = 'Microsoft Sans Serif,10'

    $lbl_email                       = New-Object system.Windows.Forms.Label
    $lbl_email.text                  = "email"
    $lbl_email.AutoSize              = $true
    $lbl_email.width                 = 25
    $lbl_email.height                = 10
    $lbl_email.location              = New-Object System.Drawing.Point($lbl_X,90)
    $lbl_email.Font                  = 'Microsoft Sans Serif,10'
    #TextBoxes
	$tb_rmv_frm                       = New-Object system.Windows.Forms.TextBox
    $tb_rmv_frm.multiline             = $false
    $tb_rmv_frm.width                 = 100
    $tb_rmv_frm.height                = 20
    $tb_rmv_frm.location              = New-Object System.Drawing.Point($tb_X,30)
    $tb_rmv_frm.Font                  = 'Microsoft Sans Serif,10'

    $tb_add_to                       = New-Object system.Windows.Forms.TextBox
    $tb_add_to.multiline             = $false
    $tb_add_to.width                 = 100
    $tb_add_to.height                = 20
    $tb_add_to.location              = New-Object System.Drawing.Point($tb_X,60)
    $tb_add_to.Font                  = 'Microsoft Sans Serif,10'

	$tb_email                        = New-Object system.Windows.Forms.TextBox
    $tb_email.multiline              = $false
    $tb_email.width                  = 100
    $tb_email.height                 = 20
    $tb_email.location               = New-Object System.Drawing.Point($tb_X,90)
    $tb_email.Font                   = 'Microsoft Sans Serif,10'
    #button(s)
    $btn_switch                      = New-Object system.Windows.Forms.Button
    $btn_switch.text                 = "Change email"
    $btn_switch.width                = 100
    $btn_switch.height               = 25
    $btn_switch.location             = New-Object System.Drawing.Point($tb_X,120)
    $btn_switch.Font                 = 'Microsoft Sans Serif,10'
    
    $Form.controls.AddRange(
        @(
            $lbl_rmv_frm,
            $lbl_add_to,
            $lbl_email,
            $tb_rmv_frm,
            $tb_add_to,
            $tb_email,
            $btn_switch
        )
    )
    # add event
    $btn_switch.Add_Click(
        {
            switch-smtp $tb_rmv_frm.text $tb_add_to.text $tb_email.text
            Add-Type -AssemblyName PresentationFramework
            [System.Windows.MessageBox]::Show('Mail alias switched')
            $form.close()
        }
    )
    $Form.ShowDialog()
}
start-form