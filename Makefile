PACKAGE=github.com/burke/zeus
VERSION=$(shell cat VERSION)
GEM=rubygem/pkg/zeus-$(VERSION).gem
GEM_LINUX=rubygem-linux/pkg/zeus-$(VERSION).gem
VAGRANT_PLUGIN=vagrant/pkg/vagrant-zeus-$(VERSION).gem
VAGRANT_PLUGIN_LINUX=vagrant-linux/pkg/vagrant-zeus-$(VERSION).gem

.PHONY: default all clean binaries compileBinaries fmt install
default: all

all: fmt binaries man/build $(GEM) $(VAGRANT_PLUGIN)

binaries: build/zeus-linux-386 build/zeus-linux-amd64 build/zeus-darwin-amd64

linux: fmt linuxBinaries man/build $(GEM_LINUX) $(VAGRANT_PLUGIN_LINUX)

linuxBinaries: build-linux

fmt:
	find . -name '*.go' | xargs -t -I@ go fmt @

man/build: Gemfile.lock
	cd man && bundle exec rake

rubygem-linux/pkg/%: \
	rubygem/man \
	rubygem/examples \
	rubygem/lib/zeus/version.rb \
	rubygem/build \
	rubygem/ext \
	Gemfile.lock
	cd rubygem && bundle install && bundle exec rake

rubygem/pkg/%: \
	rubygem/build/fsevents-wrapper \
	rubygem/man \
	rubygem/examples \
	rubygem/lib/zeus/version.rb \
	rubygem/build \
	rubygem/ext \
	Gemfile.lock
	cd rubygem && bundle exec rake

rubygem/build/fsevents-wrapper: ext/fsevents/build/Release/fsevents-wrapper
	mkdir -p $(@D)
	cp $< $@

rubygem/man: man/build
	mkdir -p $@
	cp -R $< $@

rubygem/build: binaries
	mkdir -p $@
	cp -R build/zeus-* $@

rubygem/examples: examples
	rm -rf $@
	cp -r $< $@

rubygem/ext: \
    ext/inotify-wrapper/inotify-wrapper.cpp \
    ext/inotify-wrapper/extconf.rb \
    ext/file-listener/file-listener.cpp \
    ext/file-listener/extconf.rb
	rm -rf $@
	mkdir -p $@
	cp -r ext/inotify-wrapper ext/file-listener $@

vagrant/pkg/%: \
	vagrant/build/fsevents-wrapper \
	vagrant/lib/vagrant-zeus/version.rb \
	vagrant/ext \
	Gemfile.lock
	cd vagrant && bundle install && bundle exec rake

vagrant-linux/pkg/%: \
	vagrant/lib/vagrant-zeus/version.rb \
	vagrant/ext \
	Gemfile.lock
	cd vagrant && bundle install && bundle exec rake

vagrant/build/fsevents-wrapper: ext/fsevents/build/Release/fsevents-wrapper
	mkdir -p $(@D)
	cp $< $@

vagrant/ext: \
    ext/inotify-wrapper/inotify-wrapper.cpp \
    ext/inotify-wrapper/extconf.rb
	rm -rf $@
	mkdir -p $@
	cp -r ext/inotify-wrapper $@

ext/fsevents/build/Release/fsevents-wrapper:
	cd ext/fsevents && xcodebuild

build/zeus-%: go/zeusversion/zeusversion.go compileBinaries
	@:
compileBinaries:
	gox -osarch="linux/386 linux/amd64 darwin/amd64" \
		-output="build/zeus-{{.OS}}-{{.Arch}}" \
		$(PACKAGE)/go/cmd/zeus

build-linux: go/zeusversion/zeusversion.go compileLinuxBinaries
	@:
compileLinuxBinaries:
	gox -osarch="linux/386 linux/amd64" \
		-output="build/zeus-{{.OS}}-{{.Arch}}" \
		$(PACKAGE)/go/cmd/zeus

go/zeusversion/zeusversion.go:
	mkdir -p $(@D)
	@echo 'package zeusversion\n\nconst VERSION string = "$(VERSION)"' > $@
rubygem/lib/zeus/version.rb:
	mkdir -p $(@D)
	@echo 'module Zeus\n  VERSION = "$(VERSION)"\nend' > $@
vagrant/lib/vagrant-zeus/version.rb:
	mkdir -p $(@D)
	@echo 'module VagrantPlugins\n  module Zeus\n    VERSION = "$(VERSION)"\n  end\nend' > $@


install: $(GEM)
	gem install $< --no-ri --no-rdoc

Gemfile.lock: Gemfile
	bundle check || bundle install

clean:
	rm -rf ext/fsevents/build man/build go/zeusversion build
	rm -rf rubygem/{man,build,pkg,examples,ext,lib/zeus/version.rb,MANIFEST}
	rm -rf vagrant/{build,pkg,ext,lib/vagrant-zeus/version.rb,MANIFEST}




.PHONY: dev_bootstrap
dev_bootstrap: go/zeusversion/zeusversion.go
	go get ./...
	bundle -v || gem install bundler --no-rdoc --no-ri
	bundle install
	go get github.com/mitchellh/gox
	gox -build-toolchain -osarch="linux/amd64" -osarch="darwin/amd64" -osarch="linux/386"
