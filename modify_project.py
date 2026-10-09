from pbxproj import XcodeProject
import os

project = XcodeProject.load('IOS-SwiftUI-Template.xcodeproj/project.pbxproj')

# Remove Main.swift
project.remove_files_by_path('IOS-SwiftUI-Template/Main.swift')
project.remove_files_by_path('IOS-SwiftUI-Template/IOS_SwiftUI_TemplateApp.swift')

# Add AudioEngine.swift, MainTabView.swift, AppViews.swift
project.add_file('IOS-SwiftUI-Template/AudioEngine.swift', force=False)
project.add_file('IOS-SwiftUI-Template/MainTabView.swift', force=False)
project.add_file('IOS-SwiftUI-Template/AppViews.swift', force=False)
project.add_file('IOS-SwiftUI-Template/IOS_SwiftUI_TemplateApp.swift', force=False)

project.save()
print('Modified pbxproj successfully!')
