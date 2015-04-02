angular.module('example', ['n3-line-chart'])
.controller('ExampleCtrl', function($scope, $http) {

	$scope.data = [
{x: 0, value: 4, otherValue: 14},
{x: 1, value: 8, otherValue: 1},
{x: 2, value: 15, otherValue: 11},
{x: 3, value: 16, otherValue: 147},
{x: 4, value: 23, otherValue: 87},
{x: 5, value: 42, otherValue: 45}
];

$scope.addData = function() {
	$http.get('/csv/test', {cache: false})
	.success(
		function(data, status, header, config){
			if (data) {
				console.log(data);
				data.x=$scope.data.length;
				$scope.data.push(data);
				$scope.options.axes.x.max = $scope.data.lenth;
				$scope.latestLatency = data.latencyAvg;
				$scope.lengthOfCableInM = $scope.speedOfLight * $scope.latestLatency;
				$scope.lengthOfCableInFeet = $scope.lengthOfCableInM * $scope.mToFeetFactor;
			}
		}
		);
	
//$scope.data.push({ x: $scope.data.length, value: 20, otherValue: 10});
//$scope.latestLatency = $scope.latestLatency + 1;
//$scope.options.axes.x.max = $scope.data.length;
};
setInterval($scope.addData, 1000);

$scope.options = {
	axes: {
		x: {key: 'x', labelFunction: function(value) {return value;}, type: 'linear', min: 0},//max: $scope.data.length, ticks: 2},
	y: {type: 'linear', min: 0, ticks: 5},
	y2: {type: 'linear', min: 0, ticks: [1, 2, 3, 4]}
},
	series: [
{y: 'value', color: 'steelblue', thickness: '2px', type: 'area', striped: true, label: 'Average Latency'}
//,{y: 'otherValue', axis: 'y2', color: 'lightsteelblue', visible: false, drawDots: true, dotSize: 2}
],
	lineMode: 'linear',
	tension: 0.7,
	tooltip: {mode: 'scrubber', formatter: function(x, y, series) {return 'pouet';}},
	drawLegend: true,
	drawDots: true,
	columnsHGap: 5
	};

$scope.latestLatency = 0;
$scope.speedOfLight = 299792458;
$scope.lengthOfCableInM = 0;
$scope.lengthOfCableInFeet = 0;
$scope.mToFeetFactor = 3.2808399;
});
