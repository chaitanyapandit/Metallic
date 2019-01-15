//
//  PaddedButton.swift
//  Metallic
//
//  Created by Chaitanya Pandit on 15/01/19.
//  Copyright © 2019 Chaitanya Pandit. All rights reserved.
//

import UIKit

class PaddedButton: UIButton {
   
    override var intrinsicContentSize: CGSize {
        
        get {
            var superSize = super.intrinsicContentSize
            superSize.width += self.titleEdgeInsets.left + self.titleEdgeInsets.right
            superSize.height += self.titleEdgeInsets.top + self.titleEdgeInsets.bottom

            return superSize
        }
    }
}
