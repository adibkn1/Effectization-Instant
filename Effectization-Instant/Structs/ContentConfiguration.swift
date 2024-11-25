//
//  ContentConfiguration.swift
//  QR Scanner
//
//  Created by Swarup Panda on 23/11/24.
//

import Foundation

enum ContentConfiguration {
    
    static let categoryOrder = ["AR", "CGI", "Web Apps", "AI"]
    static let contentForButtons: [String: [ImageViewContent]] = [
        "AR": [
            ImageViewContent(
                imageUrl: "https://raw.githubusercontent.com/adibkn1/FlappyBird/refs/heads/main/11.png",
                topTitle: "Snapchat Lenses",
                linkUrl: "https://www.effectizationstudio.com/work?pgid=ld4vdtuw-3c58b089-c871-4331-b183-ba3105594912"
            ),
            ImageViewContent(
                imageUrl: "https://raw.githubusercontent.com/adibkn1/FlappyBird/refs/heads/main/12.png",
                topTitle: "TikTok Filters",
                linkUrl: "https://www.effectizationstudio.com/work?pgid=ld4vdtuw-621f2a19-bd56-4464-aa09-32b959a1ea35"
            ),
            ImageViewContent(
                imageUrl: "https://raw.githubusercontent.com/adibkn1/FlappyBird/refs/heads/main/13.png",
                topTitle: "WebAR",
                linkUrl: "https://www.effectizationstudio.com/work?pgid=ld4vdtuw-d862d27b-d4fc-4257-9f57-a5e486fc6112"
            ),
            ImageViewContent(
                imageUrl: "https://raw.githubusercontent.com/adibkn1/FlappyBird/refs/heads/main/14.png",
                topTitle: "Instant AR",
                linkUrl: "https://www.effectizationstudio.com/work"
            )
            
        ],
        "CGI": [
            ImageViewContent(
                imageUrl: "https://raw.githubusercontent.com/adibkn1/FlappyBird/refs/heads/main/15.png",
                topTitle: "3D Renders",
                linkUrl: "https://www.effectizationstudio.com/work"
            ),
            ImageViewContent(
                imageUrl: "https://raw.githubusercontent.com/adibkn1/FlappyBird/refs/heads/main/16.png",
                topTitle: "CGI Videos",
                linkUrl: "https://www.effectizationstudio.com/work?pgid=ld4vdtuw-d8d6e281-6628-44d4-b193-c97ea3ac5787"
            )
        ],
        "Web Apps": [
            ImageViewContent(
                imageUrl: "https://raw.githubusercontent.com/adibkn1/FlappyBird/refs/heads/main/18.png",
                topTitle: "Hyper Casual Games",
                linkUrl: "https://en.wikipedia.org/wiki/Progressive_web_app"
            ),
            ImageViewContent(
                imageUrl: "https://raw.githubusercontent.com/adibkn1/FlappyBird/refs/heads/main/13.png",
                topTitle: "AI Web Apps",
                linkUrl: "https://www.effectizationstudio.com/work?pgid=ld4vdtuw-de76cb3d-38fb-417c-a0e7-f0d554d2557f"
            )
        ],
        "AI": [
            ImageViewContent(
                imageUrl: "https://raw.githubusercontent.com/adibkn1/FlappyBird/refs/heads/main/15.png",
                topTitle: "GenAI Video",
                linkUrl: "https://www.effectizationstudio.com/work"
            ),
            ImageViewContent(
                imageUrl: "https://raw.githubusercontent.com/adibkn1/FlappyBird/refs/heads/main/16.png",
                topTitle: "AI Content",
                linkUrl: "https://www.effectizationstudio.com/work"
            )
        ]
    ]
}
