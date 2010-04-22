if (typeof jQuery == "undefined") {
	var script = document.createElement('script');
  var url = "http://ajax.googleapis.com/ajax/libs/jquery/1.4.2/jquery.min.js"
	script.setAttribute('src', url);
	script.setAttribute('type','text/javascript');
	script.onload = function() {
		ready_to_go();
	};
	var head_doc = document.getElementsByTagName('head')[0];
	head_doc.appendChild(script);
} else {
	initialize_with_jquery();
}

function initialize_with_jquery() {
	jQuery.noConflict();
	jQuery(window).load(function($) {
		ready_to_go();
	});
}

function ready_to_go() {	
	  // Code that uses jQuery's $ can follow here.

		// cache all visible styles for box2d elements, then remove
		// their styles so they act as absolutely positioned elements
		var properties;
		var styles;
		var node;
		var style_names = [
			"border-top-color", 
			"border-right-color", 
			"border-bottom-color", 
			"border-left-color", 
			"border-top-width", 
			"border-right-width", 
			"border-bottom-width", 
			"border-left-width",
			"border-top-style", 
			"border-right-style", 
			"border-bottom-style", 
			"border-left-style",
			"background-color",
			"background-image",
			"padding-top",
			"padding-right",
			"padding-bottom",
			"padding-left",
			"margin-top",
			"margin-right",
			"margin-bottom",
			"margin-left",
			"opacity",
			"color",
			"font-weight",
			"font-size",
			"font-family",
			"list-style-image",
			"list-style-position",
			"list-style-type",
			"text-align", 
			'visibility', 
			'z-index', 
			'overflow-x', 
			'overflow-y', 
			'white-space', 
			'clip', 
			'cursor', 
			'marker-offset', 
			'background-repeat', 
			'text-transform', 
			'text-decoration', 
			'letter-spacing', 
			'word-spacing', 
			'line-height',
			'direction'
		]


		var clazzes = [];
		var cache = [];
		var totind = 0;
		var z_index = 100;
		jQuery(".box2d", document).each(function(index, element) {
			node = jQuery(element, document);
			properties = {};
			styles = {};
			var offset = node.offset(document); // relative to document
			if (offset.left == null) {
				offset = node.position();
			}
			properties["x"] = offset.left.toString() + "px";
			properties["y"] = offset.top.toString() + "px";
			properties["width"] = node.width().toString() + "px";
			properties["height"] = node.height().toString() + "px";
			var css_value = null;
			for (var i = 0; i < style_names.length; i++) {
				css_value = node.css(style_names[i]);
				if (css_value) {
					styles[style_names[i]] = css_value;
				}
			}
			styles["position"] = "absolute";
			styles["float"] = "none";
			styles["clear"] = "both";
			styles["overflow"] = "none";
			styles["display"] = "inline";

			properties["styles"] = styles;
			// copy it
			var copy = node.clone();
			// remove box2d's within the context of this
			jQuery(".box2d", copy).each(function(index, element) {
				jQuery(element).removeClass("box2d");
			});
			
			node.addClass("fixed_in_space");
			node.css("z-index", z_index++);
			copy.removeClass("box2d");
			copy.addClass("invisible_body");
			node.after(copy);
			
//			for (var i = 0; i < style_names.length; i++) {
//				node.css(style_names[i], styles[style_names[i]]);
//			}
			
//			node.insertBefore("#canvas");
			
			node.width(properties["width"]);
			node.height(properties["height"]);
			node.css("left", properties["x"]);
			node.css("top", properties["y"]);
		});
		
//		alert(clazzes.join("\n"))
		
		// do something for firefox
		if (typeof render_house_of_cards == "undefined") {
			var interval = setInterval(function() {
				if (typeof render_house_of_cards != "undefined") {
					render_house_of_cards();
					clearInterval(interval);
				}
			}, 200);
		} else {
			render_house_of_cards();
		}
		jQuery("input, textarea").click(function() {
			jQuery(this).focus();
		});
}