// TODO
// Recognise Postcode
// Cache results
// done - Display results
// done - Cursor through results and enter to select
// done - Match term anywhere (uses Ruby)
// done - Highlight match
// done - Prevent fire of search on cursor movement
// done - Position with input box
// done - Escape key closes predictions
// Inifite scroll results

$(function () {
	
	var search = $('#search-main'),
		results = $('#results'),
		active = false,
		selectedResult = null,
		pos = search.position(),
		klass = 'selected',
		minText = 2;
	
	var showResults = function () {
		active = true;
		if (search.val().length > minText) {
			return results.show();
		}
	};
	
	var hideResults = function () {
		active = false;
		return results.delay(100).fadeOut(0); // add delay so we have time to click links before they disappear. use fade, as delay needs to work with an animation so hide doesn't work.
	};
	
	var markMatched = function (term, text) {
		var reg = new RegExp(term, 'gi');
		return text.replace(reg, '<b>$&</b>');
	};

	// Only run on pages where the search box is found
	if (search.length) {
		// Position the predictions under the search box
		results.css({
			position: 'absolute',
			width: search.outerWidth() - 4,
			top: pos.top + search.outerHeight() - parseInt(search.css('borderBottomWidth')) - 3,
			left: pos.left - 1
		});
		
		search
			.keydown(function (e) {
				var path;
				switch (e.keyCode) {
					
					case 38: // up arrow
					case 40: // down
						e.preventDefault();
						
						if (!active) {
							showResults();
							return;
						}
						
						selectedResult = results.find('li.' + klass).removeClass(klass);
						
						if (selectedResult.length) {
							switch (e.keyCode) {
								case 40:
									selectedResult = selectedResult.next('li');
									break;
								case 38:
									selectedResult = selectedResult.prev('li');
							}
						} 
						// Default to the first item
						else {
							selectedResult = results.find('li:first-child');
						}
						
						selectedResult.addClass(klass);

						break;
					
					case 13: // enter
						if (active) {
							path = results.find('li.selected a').attr('href');
							
							if (path.length) {
								e.preventDefault();
								window.location.href = path;
							}
						}
						break;
					
					case 27: // esc
						hideResults();
				}
			})
			.keyup(function (e) {
				var term,
					k = e.keyCode;
				
		    	// Allow only characters, numbers, space and hyphen
				if (!((k === 8 || k === 32 || k === 189) || (k >= 65 && k <= 90) || (k >= 48 && k <= 57))) { // backspace, spacebar, hyphen (8, 32, 189), a - z (65 - 90) or 0 - 9 (48 - 57)
					return;
				}
				
				term = $(this).val();

				if (term.length > minText) {
					// Find a match server side
					$.get('/search.json', { q: term }, function (courtData) {
						var court, courts, name, i, x, len, list = [], types = ['courts', 'court_types', 'areas_of_law'];

						var listResults = function (items, type) {
							var retval = [];
							console.log(items)
							if (items.length) {

								for (i = 0; i < items.length; i++) {
									item = items[i];
									name = markMatched(term, item.name);

									retval.push('<li><a href="' + item.path + '"><i>' + type.replace(/_/g,' ') + '</i>' + name + '</a></li>');
								}

								return retval.join('')
							}
						}

						for (x in types) {
							console.log(types[x])
 							list.push(listResults(courtData[types[x]], types[x]))
						}

						if (list) {
							results.html('<ul>' + list.join('') + '</ul>');
							showResults()
						} else {
							hideResults()
						}

					});
				} else {
					hideResults();
				}
			})
			.blur(function () {
				hideResults();
			})
			.focus(function () {
				showResults();
			});
		
		$(document).keyup(function (e) {
			if (e.keyCode === 191) { // forward slash
				search.focus();
			}
		});
	};
});
