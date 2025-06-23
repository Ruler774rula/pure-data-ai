# AI Assistant dialog for Pure Data

package provide dialog_ai_assistant 0.1

package require pd_bindings

namespace eval ::dialog_ai_assistant:: {
    variable chat_history {}
    variable ai_response {"Hello, I'm the AI Assistant for Pure Data. How can I help you?"}
    
    namespace export open_assistant_dialog
}

# Send a message to the AI assistant
proc ::dialog_ai_assistant::send_message {mytoplevel} {
    variable chat_history
    variable ai_response
    
    set message [$mytoplevel.input_frame.input get 1.0 end-1c]
    if {$message ne ""} {
        # Add user message to history
        lappend chat_history [list "user" $message]
        
        # Clear input field
        $mytoplevel.input_frame.input delete 1.0 end
        
        # Update chat display
        update_chat_display $mytoplevel
        
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
    toplevel .assistant -class DialogWindow
    wm title .assistant [_ "Pure Data AI Assistant"]
    wm geometry .assistant =600x500+150+150
    wm minsize .assistant 400 300
    wm transient .assistant
    ::pd_menus::menubar_for_dialog .assistant
    .assistant configure -padx 15 -pady 15 -background #f5f5f5
    ::pd_bindings::dialog_bindings .assistant "assistant"
    
    # Title label
    label .assistant.title -text [_ "Pure Data AI Assistant"] \
        -font {$::font_family 14 bold} -foreground #333333 -background #f5f5f5
    pack .assistant.title -side top -pady 5 -anchor w
    
    # Main chat frame
    frame .assistant.chat -background #f5f5f5
    pack .assistant.chat -side top -fill both -expand 1 -pady 5
    
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
    
    # Initial welcome message
    variable chat_history
    lappend chat_history [list "ai" "Hello, I'm the AI Assistant for Pure Data. How can I help you?"]
    update_chat_display .assistant
    
    focus .assistant.input_frame.input
}