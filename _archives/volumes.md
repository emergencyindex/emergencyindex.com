---
layout: archives
name: Volumes
permalink: /archives/volumes/
banner: true
---

<div class="row">
  <div class="col s12 m6">
    <div class="collection">
      {% for volume in site.volumes %}
      {%- if volume.name and volume.name != 2017 -%}
        <a href="{{volume.url}}" class="waves-effect collection-item">{{volume.name}}</a>
      {%- endif -%}
      {% endfor %}
    </div>
  </div>
</div>
