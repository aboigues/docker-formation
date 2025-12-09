from flask import Flask, jsonify
import requests
import time
import os

from opentelemetry import trace, metrics
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
from opentelemetry.exporter.otlp.proto.grpc.trace_exporter import OTLPSpanExporter
from opentelemetry.exporter.otlp.proto.grpc.metric_exporter import OTLPMetricExporter
from opentelemetry.sdk.resources import Resource
from opentelemetry.semconv.resource import ResourceAttributes
from opentelemetry.instrumentation.flask import FlaskInstrumentor
from opentelemetry.instrumentation.requests import RequestsInstrumentor

# Configuration du Resource
resource = Resource.create({
    ResourceAttributes.SERVICE_NAME: "python-api",
    ResourceAttributes.SERVICE_VERSION: "1.0.0",
    ResourceAttributes.DEPLOYMENT_ENVIRONMENT: "production",
})

# Configuration du Tracer
trace_provider = TracerProvider(resource=resource)
otlp_endpoint = os.getenv('OTEL_EXPORTER_OTLP_ENDPOINT', 'otel-collector:4317')
trace_exporter = OTLPSpanExporter(endpoint=otlp_endpoint, insecure=True)
trace_provider.add_span_processor(BatchSpanProcessor(trace_exporter))
trace.set_tracer_provider(trace_provider)

# Configuration des Métriques
metric_reader = PeriodicExportingMetricReader(
    OTLPMetricExporter(endpoint=otlp_endpoint, insecure=True)
)
meter_provider = MeterProvider(resource=resource, metric_readers=[metric_reader])
metrics.set_meter_provider(meter_provider)

# Créer l'application Flask
app = Flask(__name__)

# Instrumenter Flask automatiquement
FlaskInstrumentor().instrument_app(app)
RequestsInstrumentor().instrument()

# Obtenir tracer et meter
tracer = trace.get_tracer(__name__)
meter = metrics.get_meter(__name__)

# Créer des métriques personnalisées
request_counter = meter.create_counter(
    "python_api_requests_total",
    description="Total number of requests"
)

processing_time = meter.create_histogram(
    "python_api_processing_seconds",
    description="Processing time in seconds"
)

@app.route('/')
def home():
    request_counter.add(1, {"endpoint": "/", "method": "GET"})
    return jsonify({"message": "Python API with OpenTelemetry"})

@app.route('/api/products')
def get_products():
    with tracer.start_as_current_span("get-products") as span:
        start_time = time.time()

        span.set_attribute("db.system", "mongodb")
        span.set_attribute("product.count", 3)

        # Simuler une requête DB
        time.sleep(0.1)

        products = [
            {"id": 1, "name": "Laptop", "price": 999},
            {"id": 2, "name": "Mouse", "price": 25},
            {"id": 3, "name": "Keyboard", "price": 75},
        ]

        duration = time.time() - start_time
        processing_time.record(duration, {"endpoint": "/api/products"})
        request_counter.add(1, {"endpoint": "/api/products", "method": "GET"})

        return jsonify(products)

@app.route('/api/products/<int:product_id>')
def get_product(product_id):
    with tracer.start_as_current_span("get-product-by-id") as span:
        start_time = time.time()

        span.set_attribute("product.id", product_id)

        # Simuler une requête DB
        time.sleep(0.05)

        # Appeler l'API Node.js (service externe)
        with tracer.start_as_current_span("call-user-service") as child_span:
            try:
                # Appeler le service demo-app
                response = requests.get(
                    f"http://demo-app:8080/api/users/{product_id}",
                    timeout=2
                )
                child_span.set_attribute("http.status_code", response.status_code)
                user_data = response.json()
            except Exception as e:
                child_span.record_exception(e)
                user_data = None

        product = {
            "id": product_id,
            "name": f"Product {product_id}",
            "price": 100 * product_id,
            "owner": user_data
        }

        duration = time.time() - start_time
        processing_time.record(duration, {"endpoint": "/api/products/:id"})
        request_counter.add(1, {"endpoint": "/api/products/:id", "method": "GET"})

        return jsonify(product)

@app.route('/health')
def health():
    return jsonify({"status": "healthy"})

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=False)
