# AI Assistant dialog for Pure Data

package provide dialog_ai_assistant 0.1

package require pd_bindings

namespace eval ::dialog_ai_assistant:: {
    variable chat_history {}
    variable ai_response {"Hello, I'm the AI Assistant for Pure Data. How can I help you?"}
    variable welcome_message {"How can I help you?"}
    variable first_message 1
    variable conversations_dir "[file join $::env(USERPROFILE) "pd-ai-conversations"]"
    variable current_conversation ""
    
    namespace export open_assistant_dialog
}

# Initialize conversation directory
proc ::dialog_ai_assistant::init_conversations_dir {} {
    variable conversations_dir
    
    # Create conversations directory if it doesn't exist
    if {![file exists $conversations_dir]} {
        file mkdir $conversations_dir
    }
}

# Generate a new conversation ID
proc ::dialog_ai_assistant::new_conversation_id {} {
    set timestamp [clock seconds]
    return "conversation_[clock format $timestamp -format {%Y%m%d_%H%M%S}]"
}

# Save current conversation to file
proc ::dialog_ai_assistant::save_conversation {} {
    variable chat_history
    variable conversations_dir
    variable current_conversation
    
    # Initialize directory if needed
    init_conversations_dir
    
    # Generate new conversation ID if none exists
    if {$current_conversation eq ""} {
        set current_conversation [new_conversation_id]
    }
    
    # Get first user message as title (or use default)
    set title "AI Conversation"
    foreach msg $chat_history {
        if {[lindex $msg 0] eq "user"} {
            set title [lindex $msg 1]
            # Limit title length
            if {[string length $title] > 30} {
                set title "[string range $title 0 27]..."
            }
            break
        }
    }
    
    # Create conversation file
    set filename [file join $conversations_dir "$current_conversation.txt"]
    set f [open $filename w]
    puts $f "TITLE: $title"
    puts $f "ID: $current_conversation"
    puts $f "DATE: [clock format [clock seconds] -format {%Y-%m-%d %H:%M:%S}]"
    puts $f "---"
    
    # Write all messages
    foreach msg $chat_history {
        set sender [lindex $msg 0]
        set content [lindex $msg 1]
        puts $f "$sender: $content"
        puts $f "---"
    }
    
    close $f
    return $filename
}

# Load conversation from file
proc ::dialog_ai_assistant::load_conversation {conversation_id} {
    variable chat_history
    variable conversations_dir
    variable current_conversation
    variable first_message
    
    # Reset chat history
    set chat_history {}
    set first_message 0
    
    # Set current conversation ID
    set current_conversation $conversation_id
    
    # Open conversation file
    set filename [file join $conversations_dir "$conversation_id.txt"]
    if {![file exists $filename]} {
        return 0
    }
    
    set f [open $filename r]
    set content [read $f]
    close $f
    
    # Skip header lines
    set lines [split $content "\n"]
    set reading_header 1
    set current_message ""
    set current_sender ""
    
    foreach line $lines {
        if {$reading_header} {
            if {$line eq "---"} {
                set reading_header 0
            }
            continue
        }
        
        if {$line eq "---"} {
            # End of message, add to history if we have one
            if {$current_sender ne ""} {
                lappend chat_history [list $current_sender $current_message]
                set current_message ""
                set current_sender ""
            }
            continue
        }
        
        # Parse message line
        if {$current_sender eq ""} {
            # This should be a sender line
            if {[string match "user:*" $line]} {
                set current_sender "user"
                set current_message [string range $line 5 end]
            } elseif {[string match "ai:*" $line]} {
                set current_sender "ai"
                set current_message [string range $line 3 end]
            }
        } else {
            # Add to current message
            append current_message "\n" $line
        }
    }
    
    # Add final message if there is one
    if {$current_sender ne ""} {
        lappend chat_history [list $current_sender $current_message]
    }
    
    return 1
}

# Get list of all saved conversations
proc ::dialog_ai_assistant::get_conversations {} {
    variable conversations_dir
    
    # Initialize directory if needed
    init_conversations_dir
    
    set conversations {}
    
    # Get all conversation files
    foreach file [glob -nocomplain -directory $conversations_dir *.txt] {
        set f [open $file r]
        set title "Untitled Conversation"
        set id [file rootname [file tail $file]]
        set date ""
        
        # Read header to get title and date
        while {[gets $f line] >= 0} {
            if {[string match "TITLE:*" $line]} {
                set title [string trim [string range $line 6 end]]
            } elseif {[string match "DATE:*" $line]} {
                set date [string trim [string range $line 5 end]]
            } elseif {$line eq "---"} {
                break
            }
        }
        close $f
        
        lappend conversations [list $id $title $date]
    }
    
    # Sort by date (newest first)
    set conversations [lsort -decreasing -index 2 $conversations]
    return $conversations
}

# Show conversation history dialog
proc ::dialog_ai_assistant::show_history_dialog {parent} {
    # Get list of conversations
    set conversations [get_conversations]
    
    # Create dialog
    set dlg .conversation_history
    catch {destroy $dlg}
    
    toplevel $dlg -class DialogWindow
    wm title $dlg [_ "Conversation History"]
    wm geometry $dlg =400x300+200+200
    wm transient $dlg $parent
    wm protocol $dlg WM_DELETE_WINDOW "destroy $dlg"
    
    # Create listbox with scrollbar
    frame $dlg.list_frame
    listbox $dlg.list_frame.listbox -yscrollcommand "$dlg.list_frame.scroll set" \
        -width 40 -height 15 -font {$::font_family 11} -borderwidth 1 \
        -relief solid -highlightthickness 1 -highlightcolor #4a86e8
    scrollbar $dlg.list_frame.scroll -command "$dlg.list_frame.listbox yview"
    
    # Populate listbox
    foreach conv $conversations {
        set id [lindex $conv 0]
        set title [lindex $conv 1]
        set date [lindex $conv 2]
        $dlg.list_frame.listbox insert end "$title ($date)"
    }
    
    # Buttons
    frame $dlg.buttons
    button $dlg.buttons.load -text [_ "Load"] -command {
        set idx [.conversation_history.list_frame.listbox curselection]
        if {$idx ne ""} {
            set conversations [::dialog_ai_assistant::get_conversations]
            set selected [lindex $conversations $idx]
            set id [lindex $selected 0]
            ::dialog_ai_assistant::load_conversation $id
            ::dialog_ai_assistant::update_chat_display .assistant
            destroy .conversation_history
        }
    }
    button $dlg.buttons.cancel -text [_ "Cancel"] -command "destroy $dlg"
    
    # Pack everything
    pack $dlg.list_frame.scroll -side right -fill y
    pack $dlg.list_frame.listbox -side left -fill both -expand 1
    pack $dlg.list_frame -side top -fill both -expand 1 -padx 10 -pady 10
    
    pack $dlg.buttons.cancel -side right -padx 5
    pack $dlg.buttons.load -side right -padx 5
    pack $dlg.buttons -side bottom -fill x -padx 10 -pady 10
    
    # Double-click to load
    bind $dlg.list_frame.listbox <Double-1> {
        .conversation_history.buttons.load invoke
    }
    
    # Focus listbox
    focus $dlg.list_frame.listbox
}

# Send a message to the AI assistant
proc ::dialog_ai_assistant::send_message {mytoplevel} {
    variable chat_history
    variable ai_response
    variable first_message
    variable current_conversation
    
    set message [$mytoplevel.input_frame.input get 1.0 end-1c]
    if {$message ne ""} {
        # If this is the first message, clear welcome screen
        if {$first_message} {
            set first_message 0
            # Hide welcome message
            pack forget $mytoplevel.welcome_frame
            # Show chat display
            pack $mytoplevel.chat -side top -fill both -expand 1 -pady 5
        }
        
        # Add user message to history
        lappend chat_history [list "user" $message]
        
        # Clear input field
        $mytoplevel.input_frame.input delete 1.0 end
        
        # Update chat display
        update_chat_display $mytoplevel
        
        # Save conversation
        save_conversation
        
        # Here we would normally send the message to an AI backend
        # For now, just return a dummy response
        after 500 [list ::dialog_ai_assistant::receive_ai_response $mytoplevel \
            "This is a test response. In the future, this will connect to a real AI system."]
    }
}

# Receive response from AI assistant
proc ::dialog_ai_assistant::receive_ai_response {mytoplevel response} {
    variable chat_history
    variable ai_response
    
    # Add AI response to history
    lappend chat_history [list "ai" $response]
    
    # Update chat display
    update_chat_display $mytoplevel
}

# Update the chat display with the current history
proc ::dialog_ai_assistant::update_chat_display {mytoplevel} {
    variable chat_history
    variable first_message
    
    # If this is not the first message, make sure chat is visible
    if {!$first_message} {
        # Hide welcome frame if it exists
        if {[winfo exists $mytoplevel.welcome_frame]} {
            pack forget $mytoplevel.welcome_frame
        }
        # Show chat display
        pack $mytoplevel.chat -side top -fill both -expand 1 -pady 5
    }
    
    # Clear current display
    $mytoplevel.chat.display configure -state normal
    $mytoplevel.chat.display delete 1.0 end
    
    # Add each message to the display with appropriate formatting
    foreach msg $chat_history {
        set sender [lindex $msg 0]
        set content [lindex $msg 1]
        
        if {$sender eq "user"} {
            # User message - right aligned with different color
            $mytoplevel.chat.display insert end "\n"
            $mytoplevel.chat.display insert end "User:\n" "user_name"
            $mytoplevel.chat.display insert end $content "user_msg"
        } else {
            # AI message - left aligned
            $mytoplevel.chat.display insert end "\n"
            $mytoplevel.chat.display insert end "AI Assistant:\n" "ai_name"
            $mytoplevel.chat.display insert end $content "ai_msg"
        }
        $mytoplevel.chat.display insert end "\n\n"
    }
    
    # Scroll to bottom
    $mytoplevel.chat.display see end
    $mytoplevel.chat.display configure -state disabled
}

# Cancel/close the assistant dialog
proc ::dialog_ai_assistant::cancel {mytoplevel} {
    destroy $mytoplevel
    ::pd_bindings::check_quit_after_window_destroyed
}

# Open the assistant dialog
proc ::dialog_ai_assistant::open_assistant_dialog {mytoplevel} {
    if {[winfo exists .assistant]} {
        wm deiconify .assistant
        raise .assistant
        focus .assistant.input_frame.input
    } else {
        create_dialog $mytoplevel
    }
}

# Create the assistant dialog window
proc ::dialog_ai_assistant::create_dialog {mytoplevel} {
    variable first_message
    variable welcome_message
    
    # Initialize first message flag
    set first_message 1
    
    toplevel .assistant -class DialogWindow
    wm title .assistant [_ "Pure Data AI Assistant"]
    wm geometry .assistant =600x500+150+150
    wm minsize .assistant 400 300
    wm transient .assistant
    ::pd_menus::menubar_for_dialog .assistant
    .assistant configure -padx 15 -pady 15 -background #f5f5f5
    ::pd_bindings::dialog_bindings .assistant "assistant"
    
    # Header frame with title and history button
    frame .assistant.header -background #f5f5f5
    pack .assistant.header -side top -fill x -pady 5
    
    # Title label
    label .assistant.header.title -text [_ "Pure Data AI Assistant"] \
        -font {$::font_family 14 bold} -foreground #333333 -background #f5f5f5
    pack .assistant.header.title -side left -pady 5
    
    # History button
    button .assistant.header.history -text [_ "History"] \
        -font {$::font_family 10} -padx 10 -pady 2 \
        -background #f0f0f0 -activebackground #e0e0e0 \
        -relief flat -borderwidth 1 -highlightthickness 0 \
        -command "::dialog_ai_assistant::show_history_dialog .assistant"
    pack .assistant.header.history -side right -padx 5
    
    # New Chat button
    button .assistant.header.newchat -text [_ "New Chat"] \
        -font {$::font_family 10} -padx 10 -pady 2 \
        -background #f0f0f0 -activebackground #e0e0e0 \
        -relief flat -borderwidth 1 -highlightthickness 0 \
        -command {
            set ::dialog_ai_assistant::first_message 1
            set ::dialog_ai_assistant::current_conversation ""
            set ::dialog_ai_assistant::chat_history {}
            
            # Hide chat display
            pack forget .assistant.chat
            # Show welcome message
            pack .assistant.welcome_frame -side top -fill both -expand 1 -pady 20
        }
    pack .assistant.header.newchat -side right -padx 5
    
    # Welcome frame (shown on first open)
    frame .assistant.welcome_frame -background #f5f5f5
    pack .assistant.welcome_frame -side top -fill both -expand 1 -pady 20
    
    # Center welcome message
    frame .assistant.welcome_frame.center -background #f5f5f5
    pack .assistant.welcome_frame.center -side top -expand 1 -fill both
    
    # AI Assistant logo/title
    label .assistant.welcome_frame.center.logo -text [_ "AI Assistant"] \
        -font {$::font_family 24 bold} -foreground #4a86e8 -background #f5f5f5
    pack .assistant.welcome_frame.center.logo -side top -pady 10
    
    # Welcome message
    label .assistant.welcome_frame.center.message -text $welcome_message \
        -font {$::font_family 14} -foreground #555555 -background #f5f5f5
    pack .assistant.welcome_frame.center.message -side top -pady 5
    
    # Main chat frame (hidden initially)
    frame .assistant.chat -background #f5f5f5
    
    # Chat display area with scrollbar
    text .assistant.chat.display -yscrollcommand ".assistant.chat.scroll set" \
        -width 50 -height 20 -wrap word -state disabled \
        -font {$::font_family 12} -padx 10 -pady 10 \
        -relief flat -highlightthickness 1 -highlightcolor #cccccc \
        -background white -borderwidth 0
    scrollbar .assistant.chat.scroll -command ".assistant.chat.display yview" \
        -troughcolor #f0f0f0 -activebackground #999999 -background #dddddd
    
    # Configure tags for message styling
    .assistant.chat.display tag configure user_msg -justify right -foreground black \
        -background #e6e6e6 -lmargin2 100 -rmargin 10 -relief raised -borderwidth 1 \
        -spacing1 10 -spacing3 15 -font {$::font_family 11}
    .assistant.chat.display tag configure ai_msg -justify left -foreground black \
        -background #d1e0ff -lmargin1 10 -rmargin 100 -relief raised -borderwidth 1 \
        -spacing1 10 -spacing3 15 -font {$::font_family 11}
    
    # Configure additional tags for sender names
    .assistant.chat.display tag configure user_name -justify right -foreground #555555 \
        -lmargin2 100 -rmargin 10 -font {$::font_family 10 bold} -spacing1 5
    .assistant.chat.display tag configure ai_name -justify left -foreground #555555 \
        -lmargin1 10 -rmargin 100 -font {$::font_family 10 bold} -spacing1 5
    
    # Input area frame
    frame .assistant.input_frame -background #f5f5f5
    pack .assistant.input_frame -side bottom -fill x -pady 5
    
    # Input area
    text .assistant.input_frame.input -height 3 -wrap word \
        -font {$::font_family 12} -padx 8 -pady 8 \
        -relief flat -highlightthickness 1 -highlightcolor #4a86e8 \
        -background white -borderwidth 0
    
    # Send button
    button .assistant.input_frame.send -text [_ "Send"] \
        -font {$::font_family 11 bold} -padx 15 -pady 5 \
        -background #4a86e8 -foreground white -activebackground #3a76d8 -activeforeground white \
        -relief flat -borderwidth 0 -highlightthickness 0 \
        -command "::dialog_ai_assistant::send_message .assistant"
    
    # Pack everything
    pack .assistant.chat.scroll -side right -fill y
    pack .assistant.chat.display -side top -fill both -expand 1
    pack .assistant.input_frame.input -side left -fill both -expand 1 -padx 5 -pady 5
    pack .assistant.input_frame.send -side right -padx 5 -pady 5
    
    # Add a subtle separator between chat and input
    frame .assistant.separator -height 1 -background #dddddd
    pack .assistant.separator -before .assistant.input_frame -fill x -padx 5
    
    # Bindings
    bind .assistant <$::modifier-Key-w> "::dialog_ai_assistant::cancel .assistant"
    bind .assistant.input_frame.input <Return> "::dialog_ai_assistant::send_message .assistant; break"
    bind .assistant.input_frame.input <Shift-Return> {%W insert insert "\n"; break}
    
    # Set protocol for window close button
    wm protocol .assistant WM_DELETE_WINDOW "::dialog_ai_assistant::cancel .assistant"
    
    # Add hover effect to send button
    bind .assistant.input_frame.send <Enter> {%W configure -background #3a76d8}
    bind .assistant.input_frame.send <Leave> {%W configure -background #4a86e8}
    
    # Initialize conversations directory
    init_conversations_dir
    
    # Set focus to input
    focus .assistant.input_frame.input
}