---
layout: archives
name: Volumes
permalink: /archive/volumes/
banner: true
---

<div class="row">
  <div class="col s12 m10 l8">
    <div class="collection">
      {% for volume in site.volumes reversed %}
        <a href="{{volume.url}}" class="waves-effect collection-item">{{volume.name}}</a>
      {% endfor %}
    </div>
  </div>
</div>
