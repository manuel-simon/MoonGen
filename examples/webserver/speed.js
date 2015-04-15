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

            
    $scope.histData = [
    //{x: 1, y: 4, otherValue: 14},
    //{x: 2, y: 8, otherValue: 1},
    //{x: 3, y: 15, otherValue: 11},
    //{x: 4, y: 16, otherValue: 147},
    //{x: 5, y: 23, otherValue: 87},
    //{x: 6, y: 42, otherValue: 45},
    //{x: 7, y: 42, otherValue: 45},
    //{x: 8, y: 42, otherValue: 45},
    //{x: 9, y: 42, otherValue: 45},
    //{x: 10, y: 42, otherValue: 45},
    //{x: 11, y: 40, otherValue: 45},
    //{x: 12, y: 38, otherValue: 45},
    //{x: 13, y: 36, otherValue: 45},
    //{x: 14, y: 36, otherValue: 45}
    ];

$scope.addData = function() {
	$http.get('/data/throughput', {cache: false})
	.success(
		function(data, status, header, config){
			if (data) {
				console.log(data);
				data.y = data.y / 1000;
				$scope.data.push(data);
				if ($scope.data.length > $scope.numPointsDisplayed + 1) {
					$scope.data.splice(0, 1);
					$scope.options.axes.x.min = $scope.data[0].x;	
				} else {
					$scope.options.axes.x.min = $scope.data[$scope.data.length-1].x- $scope.numPointsDisplayed;	
				}
				$scope.options.axes.x.max = $scope.data[$scope.data.length-1].x;
				$scope.latestThroughput = data.y * 1000;
			}
		}
		);
};
setInterval($scope.addData, 1000);
            
$scope.addHistData = function() {
            $http.get('/data/latency', {cache: false})
            .success(
                     function(data, status, header, config){
                     	console.log("latency data:" + data.histo.toString());
			     if (data) {$scope.histData = data.histo;}
                     }
                    );
            }
setInterval($scope.addHistData, 5000);
            
$scope.addSetting = function() {
	console.log("this is a test to test if function is called");
	//$scope.latestThroughput = $scope.setThroughput;
	//$scope.$apply();
    	//erase histogram after changing settings
    	if ($scope.histData.length > 0) $scope.histData.splice(0, $scope.histData.length);
	$http.post('/post/setting', {setThroughput: + $scope.setThroughput})
		.success(
				function (data, status, header, config) {
					console.log("addSetting executed.");
				}
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
            
$scope.histOptions = {
            axes: {
            x: {key: 'x', labelFunction: function(y) {return y;}, type: 'column'},//max: $scope.data.length, ticks: 2},
            y: {type: 'column', min: 0},
            },
            series: [
                     {y: 'y', color: 'green', thickness: '2px', type: 'column', striped: false, label: 'Latency'}
                     ],
            lineMode: 'linear',
            tension: 0.7,
            tooltip: {mode: 'scrubber', formatter: function(x, y, series) {return y;}},
            drawLegend: true,
            drawDots: true,
            columnsHGap: 1
            };
$scope.setThroughput = 0;
$scope.latestThroughput = 0;
$scope.numPointsDisplayed = 60;
});
