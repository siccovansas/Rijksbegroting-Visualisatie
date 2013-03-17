//$(document).ready(function(){



  var loadLineItems = function(){
    var items = []
    d3.csv('/us_budget_expenses_2013.csv', function(csv){
      $.each(csv, function(row, data){
        items.push(data);
      });

      //node = root = csv;
    });
    return items;
  };

  line_items = loadLineItems();


  var getLineItem = function(item){
    return {"agency_name" : item['Agency Name'],
            "bureau_name" : item['Bureau Name'],
            "name" : item['Account Name']};
  };

  var getYearlyLineItem = function(item, year){
    var line_item_cost = getLineItem(item);
    line_item_cost.size = parseInt(item[year].replace(',',''));
    return line_item_cost;
  };

  var getYearlyExpenses = function(year){
    var yearly_budget = line_items.map(
      function(x) { return getYearlyLineItem(x, year)}
    );

    var noZeroSize = _.filter(yearly_budget, function(x){ return x.size > 0;});
    return noZeroSize;
  };

  var filterZeroSize = function(nestedData){

  };

  var getYearlyData = function(year){
    var d = getNestedData(year);

    var data = _.map(d, function(val , key){
      var agencyChildren = getAgencyChildren(val);
      return {
        "name" : key,
        "children" : agencyChildren,
        "size" : _.reduce(agencyChildren, function(sum, num){
        return sum + num.size;},0)
      };
    });

    var sortedData = _.sortBy(data, function(d){return -1 * d.size; });

    return {"name" : "us_budget", "children" : sortedData};
    //return data;
  };

  var getNestedData = function(year){
    var data2 = d3.nest()
      .key(function(d) {return d['agency_name'];})
      .key(function(d) {return d['bureau_name'];})
      .map(getYearlyExpenses(year));
    return data2;
  };

  var getAgencyChildren = function(r){
   var agency_children = _.map(r, function(val, key){
     return {
       "name" : key,
       "children" : val,
       "size" : _.reduce(val, function(sum, num){
         return sum + num.size;}, 0)
     };
   });

   return agency_children;
  };

// http://bost.ocks.org/mike/treemap/
  var setupVisual = function(){
    var w = 1400,
        h = 1200,
        x = d3.scale.linear().range([0, w]),
        y = d3.scale.linear().range([0, h]),
        color = d3.scale.category20c(),
        root,
        node;

    var treemap = d3.layout.treemap()
        .round(false)
        .size([w, h])
        .sticky(true)
        .value(function(d) { return d.size; });

    var svg = d3.select("body").append("div")
        .attr("class", "chart")
        .style("width", w + "px")
        .style("height", h + "px")
      .append("svg:svg")
        .attr("width", w)
        .attr("height", h)
      .append("svg:g")
        .attr("transform", "translate(.5,.5)");

    var mainData = getYearlyData('2010');
    //console.log(mainData);
    var nodes = treemap.nodes(mainData);

    //console.log(nodes);

    var cell = svg.selectAll("g")
        .data(nodes)
      .enter().append("svg:g")
        .attr("class", "cell")
        .attr("transform", function(d) { return "translate(" + d.x + "," + d.y + ")"; })
        .on("click", function(d) { return zoom(node == d.parent ? root : d.parent); });

    cell.append("svg:rect")
        .attr("width", function(d) { return d.dx ; })
        .attr("height", function(d) { return d.dy ; })
        .style("fill", function(d) { return color(d.size); });

    cell.append("svg:text")
        .attr("x", function(d) { return d.dx / 2; })
        .attr("y", function(d) { return d.dy / 2; })
        .attr("dy", ".35em")
        .attr("text-anchor", "middle")
        .text(function(d) {
          var msg = d.name;
          if(d.size){
            msg += " : $";
            msg += d.size.toFixed(0).replace(/(\d)(?=(\d{3})+\b)/g,'$1,');
          }
          return msg;
        })
        .style("opacity", function(d) { d.w = this.getComputedTextLength(); return d.dx > d.w ? 1 : 0; });

    cell.append("svg:title")
        .text(function(d) {
          var msg = d.name;
          if(d.size){
            msg += " : $";
            msg += d.size.toFixed(0).replace(/(\d)(?=(\d{3})+\b)/g,'$1,');
          }
          return msg;
        });

    var size = function(d){return d.size;};

    //var zoom = function(d) {
      //var kx = w / d.dx, ky = h / d.dy;
      //x.domain([d.x, d.x + d.dx]);
      //y.domain([d.y, d.y + d.dy]);

      //var t = svg.selectAll("g.cell").transition()
          //.duration(d3.event.altKey ? 7500 : 750)
          //.attr("transform", function(d) { return "translate(" + x(d.x) + "," + y(d.y) + ")"; });

      //t.select("rect")
          //.attr("width", function(d) { return kx * d.dx - 1; })
          //.attr("height", function(d) { return ky * d.dy - 1; })

      //t.select("text")
          //.attr("x", function(d) { return kx * d.dx / 2; })
          //.attr("y", function(d) { return ky * d.dy / 2; })
          //.style("opacity", function(d) { return kx * d.dx > d.w ? 1 : 0; });

      //node = d;
      //d3.event.stopPropagation();
    //}
  };
//});
