# Chart showcase

Markdown4D renders Chart.js-style configs **natively** in the preview — no
browser, no chart.js. Below is every supported chart type.

## Bar (grouped)

```chart
{"type":"chart","data":{"type":"bar","data":{"labels":["Q1","Q2","Q3","Q4"],"datasets":[{"label":"North","data":[12,19,15,22],"backgroundColor":"#4e79a7"},{"label":"South","data":[8,14,20,17],"backgroundColor":"#f28e2b"}]},"options":{"plugins":{"title":{"display":true,"text":"Quarterly sales"},"legend":{"display":true,"position":"top"}}}}}
```

## Bar (stacked)

```chart
{"type":"chart","data":{"type":"bar","data":{"labels":["Q1","Q2","Q3"],"datasets":[{"label":"A","data":[3,5,2]},{"label":"B","data":[4,2,6]},{"label":"C","data":[2,3,4]}]},"options":{"scales":{"x":{"stacked":true},"y":{"stacked":true}}}}}
```

## Horizontal bar (new)

```chart
{"type":"chart","data":{"type":"bar","data":{"labels":["Alpha","Beta","Gamma","Delta"],"datasets":[{"label":"Score","data":[42,58,35,67]}]},"options":{"indexAxis":"y"}}}
```

## Line

```chart
{"type":"chart","data":{"type":"line","data":{"labels":["Mon","Tue","Wed","Thu","Fri"],"datasets":[{"label":"Visitors","data":[120,150,110,180,160],"borderColor":"#59a14f"}]}}}
```

## Area — line + fill (new)

```chart
{"type":"chart","data":{"type":"line","data":{"labels":["Jan","Feb","Mar","Apr","May"],"datasets":[{"label":"Revenue","data":[30,45,38,60,52],"borderColor":"#e15759","fill":true}]}}}
```

## Pie

```chart
{"type":"chart","data":{"type":"pie","data":{"labels":["Chrome","Firefox","Safari","Edge"],"datasets":[{"data":[63,12,15,10]}]}}}
```

## Doughnut

```chart
{"type":"chart","data":{"type":"doughnut","data":{"labels":["Done","In progress","Todo"],"datasets":[{"data":[45,30,25]}]}}}
```

## Radar (new)

```chart
{"type":"chart","data":{"type":"radar","data":{"labels":["Speed","Power","Range","Agility","Defense"],"datasets":[{"label":"Model X","data":[8,6,9,7,5]},{"label":"Model Y","data":[6,9,5,8,7]}]}}}
```

## Scatter (new)

```chart
{"type":"chart","data":{"type":"scatter","data":{"datasets":[{"label":"Set A","data":[{"x":1,"y":2},{"x":3,"y":5},{"x":5,"y":3},{"x":7,"y":8}]},{"label":"Set B","data":[{"x":2,"y":6},{"x":4,"y":2},{"x":6,"y":7},{"x":8,"y":4}]}]}}}
```
