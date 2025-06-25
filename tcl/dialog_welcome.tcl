# dialog_welcome.tcl
# A welcome dialog that shows when Pd starts

package provide dialog_welcome 0.1

package require pd_bindings

namespace eval ::dialog_welcome:: {
    namespace export open_welcome_dialog
    namespace export create_dialog
    
    variable welcome_window ".welcome"
}

# Create the welcome dialog
proc ::dialog_welcome::create_dialog {} {
    variable welcome_window
    
    # If the window already exists, just raise it
    if {[winfo exists $welcome_window]} {
        wm deiconify $welcome_window
        raise $welcome_window
        focus $welcome_window
        return
    }
    
    # Create the toplevel window
    toplevel $welcome_window -class DialogWindow
    wm title $welcome_window [_ "Welcome to Pure Data"]
    wm minsize $welcome_window 400 300
    wm geometry $welcome_window 500x350+300+300
    wm protocol $welcome_window WM_DELETE_WINDOW {
        # Hide the window when closed, don't destroy it
        wm withdraw .welcome
        # Check if we should quit Pd (only if this is the only window)
        ::pd_bindings::check_quit_after_window_destroyed
    }
    
    # Main frame
    frame $welcome_window.main -padx 20 -pady 20
    pack $welcome_window.main -fill both -expand 1
    
    # Title and welcome message
    label $welcome_window.main.title -text "Pure Data" -font {-size 24 -weight bold}
    pack $welcome_window.main.title -pady 10
    
    set version "${::PD_MAJOR_VERSION}.${::PD_MINOR_VERSION}.${::PD_BUGFIX_VERSION}${::PD_TEST_VERSION}"
    label $welcome_window.main.version -text "Version $version" -font {-size 12}
    pack $welcome_window.main.version -pady 5
    
    label $welcome_window.main.welcome -text [_ "Welcome! Choose an option to begin:"] -font {-size 12}
    pack $welcome_window.main.welcome -pady 10
    
    # Buttons frame
    frame $welcome_window.main.buttons -pady 10
    pack $welcome_window.main.buttons -fill x -expand 1
    
    # New button
    button $welcome_window.main.buttons.new -text [_ "New Patch"] -width 15 -height 2 \
        -command {
            ::pd_menucommands::menu_new
            wm withdraw .welcome
            # No need to check for quit here as a new patch will be created
        }
    pack $welcome_window.main.buttons.new -side top -pady 5 -fill x
    
    # Open button
    button $welcome_window.main.buttons.open -text [_ "Open Patch..."] -width 15 -height 2 \
        -command {
            ::pd_menucommands::menu_open
            wm withdraw .welcome
            # No need to check for quit here as a patch will be opened
        }
    pack $welcome_window.main.buttons.open -side top -pady 5 -fill x
    
    # Recent files frame
    labelframe $welcome_window.main.recent -text [_ "Recent Files"] -padx 10 -pady 10
    pack $welcome_window.main.recent -side top -fill both -expand 1 -pady 10
    
    # Create a listbox for recent files
    listbox $welcome_window.main.recent.list -height 5 -width 40 -selectmode single \
        -yscrollcommand "$welcome_window.main.recent.scroll set"
    scrollbar $welcome_window.main.recent.scroll -command "$welcome_window.main.recent.list yview"
    pack $welcome_window.main.recent.scroll -side right -fill y
    pack $welcome_window.main.recent.list -side left -fill both -expand 1
    
    # Populate the recent files list
    populate_recent_files
    
    # Bind double-click on recent files list
    bind $welcome_window.main.recent.list <Double-1> {
        set idx [.welcome.main.recent.list curselection]
        if {$idx ne ""} {
            set filename [lindex $::recentfiles_list $idx]
            open_file $filename
            wm withdraw .welcome
            # No need to check for quit here as a patch will be opened
        }
    }
    
    # Don't show this dialog again checkbox
    checkbutton $welcome_window.main.dontshow -text [_ "Don't show this window on startup"] \
        -variable ::dialog_welcome::dontshow \
        -command {
            ::pd_guiprefs::write "welcome_screen" $::dialog_welcome::dontshow
        }
    pack $welcome_window.main.dontshow -side bottom -anchor w -pady 10
    
    # Initialize the dontshow variable from preferences
    set ::dialog_welcome::dontshow [::pd_guiprefs::read "welcome_screen" 0]
    
    # Center the window on the screen
    ::pdwindow::busygrab
    raise $welcome_window
    focus $welcome_window
    ::pdwindow::busyrelease
}

# Populate the recent files listbox
proc ::dialog_welcome::populate_recent_files {} {
    variable welcome_window
    
    $welcome_window.main.recent.list delete 0 end
    
    foreach filename $::recentfiles_list {
        $welcome_window.main.recent.list insert end [file tail $filename]
    }
}

# Open the welcome dialog
proc ::dialog_welcome::open_welcome_dialog {} {
    # Check if we should show the welcome screen
    set dontshow [::pd_guiprefs::read "welcome_screen" 0]
    
    # Ensure dontshow is a valid boolean (0 or 1)
    if {$dontshow eq ""} {
        set dontshow 0
    }
    
    if {$dontshow == 0} {
        create_dialog
    }
}