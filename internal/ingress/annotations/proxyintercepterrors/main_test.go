/*
Copyright 2017 The Kubernetes Authors.
Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at
    http://www.apache.org/licenses/LICENSE-2.0
Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package proxyintercepterrors

import (
	"testing"

	api "k8s.io/api/core/v1"
	networking "k8s.io/api/networking/v1"
	meta_v1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/ingress-nginx/internal/ingress/annotations/parser"
	"k8s.io/ingress-nginx/internal/ingress/resolver"
)

func buildIngress() *networking.Ingress {
	return &networking.Ingress{
		ObjectMeta: meta_v1.ObjectMeta{
			Name:      "foo",
			Namespace: api.NamespaceDefault,
		},
		Spec: networking.IngressSpec{
			DefaultBackend: &networking.IngressBackend{
				Service: &networking.IngressServiceBackend{
					Name: "default-backend",
					Port: networking.ServiceBackendPort{
						Number: 80,
					},
				},
			},
		},
	}
}

func TestParseAnnotations(t *testing.T) {
	ing := buildIngress()

	_, err := NewParser(&resolver.Mock{}).Parse(ing)
	if err != nil {
		t.Errorf("unexpected error: %v", err)
	}

	data := map[string]string{}
	data[parser.GetAnnotationWithPrefix("proxy-intercept-errors")] = "true"
	ing.SetAnnotations(data)
	// test ingress using the annotation without a TLS section
	_, err = NewParser(&resolver.Mock{}).Parse(ing)
	if err != nil {
		t.Errorf("unexpected error parsing ingress with proxy intercept errors")
	}
}