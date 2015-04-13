angular.module('example', ['n3-line-chart', 'ui.slider'])
.controller('ExampleCtrl', function($scope, $http) {

	$scope.data = [
	//{x: 0, value: 4, otherValue: 14},
	//{x: 1, value: 8, otherValue: 1},
	//{x: 2, value: 15, otherValue: 11},
	//{x: 3, value: 16, otherValue: 147},
	//{x: 4, value: 23, otherValue: 87},
	//{x: 5, value: 42, otherValue: 45}
	];


$scope.addData = function() {
	$http.get('/csv/test', {cache: false})
	.success(
		function(data, status, header, config){
			if (data) {
				console.log(data);
				$scope.data.push(data);
				if ($scope.data.length > $scope.numPointsDisplayed + 1) {
					$scope.data.splice(0, 1);
					$scope.options.axes.x.min = $scope.data[0].x;	
				} else {
					$scope.options.axes.x.min = $scope.data[$scope.data.length-1].x- $scope.numPointsDisplayed;	
				}
				$scope.options.axes.x.max = $scope.data[$scope.data.length-1].x;
				$scope.latestThroughput = data.y;
			}
		}
);
};
setInterval($scope.addData, 1000);

$scope.Settings = function() {
            $http.post('/post/setting', {cache: false, msg:'{setThroughput:' + setThroughput + '}'})
            .success(
                     function(data, status, header, config){}
                     );
            };
$scope.options = {
	axes: {
		x: {key: 'x', labelFunction: function(y) {return y;}, type: 'linear', min: 0},//max: $scope.data.length, ticks: 2},
	y: {type: 'linear', min: 0},
},
	series: [
{y: 'y', color: 'steelblue', thickness: '2px', type: 'area', striped: false, label: 'Throughput'}
],
	lineMode: 'linear',
	tension: 0.7,
	tooltip: {mode: 'scrubber', formatter: function(x, y, series) {return 'latency';}},
	drawLegend: true,
	drawDots: true,
	columnsHGap: 5
	};

$scope.setThroughput = 0;
$scope.latestThroughput = 0;
$scope.numPointsDisplayed = 60;
});
