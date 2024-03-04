---
layout: page
title: Videos
permalink: /videos/
---

Videos from our projects and experiment.

{% for video_hash in site.data.videos %}
{% assign video_category = video_hash[1] %}

## {{video_category.title}}

<table>
<tr>
	<th>Thumbnail</th>
	<th>Name</th>
	<th>Date</th>
	<th>Description</th>
</tr>

{% for video in video_category.videos %}
<tr>
	<td>{{video.Thumbnail}}</td>
	<td><a href="{{video.Links}}">{{video.Name}}</a></td>
	<td>{{video.Date}}</td>
	<td>{{video.Description}}</td>
</tr>
{% endfor %} 
</table>

{% endfor %}